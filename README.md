# alidns-webhook-with-role
This repo is based on [pragkent/alidns-webhook](https://github.com/pragkent/alidns-webhook), added ram role authentication support

## Why
if the kubernetes cluster is running on aliyun ecs or ack,we can use EcsRamRole instead of accesskey ,which  reduce attack-surface and forget about key rotation


## How
### Install cert-manager
follow  official document  https://cert-manager.io/docs/releases/

### Install alidns-webhook
```bash
kubectl apply -f https://raw.githubusercontent.com/ri0day/alidns-webhook-with-role/master/deploy/bundle.yaml
```
### config authmode in issuer or clusterissuer


**AK mode Example:**

secret.yaml
  ```yaml
  apiVersion: v1
  kind: Secret
  metadata:
    name: alidns-secret
    namespace: cert-manager
  data:
    access-key: YOUR_ACCESS_KEY
    secret-key: YOUR_SECRET_KEY
  ```
clusterissuer.yaml
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-staging
  spec:
    acme:
      # Change to your letsencrypt email
      email: certmaster@example.com
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-staging-account-key
      solvers:
      - dns01:
          webhook:
            groupName: acme.yourcompany.com
            solverName: alidns
            config:
              authmode: ak
              region: "cn-hangzhou"
              accessKeySecretRef:
                name: alidns-secret
                key: access-key
              secretKeySecretRef:
                name: alidns-secret
                key: secret-key
  ```
----
**Role mode Example for self-hosted kubernetes on aliyun**

1. create an ram role(`cert-manager-webhook-role`) trust ecs service ,allow pods can assume to role 
```bash
aliyun ram CreateRole --region cn-hangzhou --RoleName 'cert-manager-webhook-role' --Description 'cert-manager webhook add dns records for dns validation' --AssumeRolePolicyDocument '{"Statement":[{"Action":"sts:AssumeRole","Effect":"Allow","Principal":{"Service":["ecs.aliyuncs.com"]}}],"Version":"1"}'
```
2. attach policy to role,for simplicity i will use built-in policy `AliyunDNSFullAccess`,you may craft you own policy to restrict the permission of you role
```bash
aliyun ram AttachPolicyToRole --region cn-hangzhou --PolicyType System --PolicyName AliyunDNSFullAccess --RoleName 'cert-manager-webhook-role'
```
3. attch role to kubernetes worker nodes
```bash
aliyun ecs AttachInstanceRamRole --region cn-hangzhou --RegionId 'cn-hangzhou' --RamRoleName 'cert-manager-webhook-role' --InstanceIds '["instanceid-1","instanceid-2"]'
```
4. create an clusterissuer with  `authmode=role`
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: letsencrypt-staging
  spec:
    acme:
      # Change to your letsencrypt email
      email: certmaster@example.com
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      privateKeySecretRef:
        name: letsencrypt-staging-account-key
      solvers:
      - dns01:
          webhook:
            groupName: acme.yourcompany.com
            solverName: alidns
            config:
              authmode: role
              region: "cn-hangzhou"
              rolename: cert-manager-dns-role
  ```
 5. make an certificate request in default namespace
```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: yourdomain-tls
  namespace: default
spec:
  secretName: yourdomain-com-tls
  commonName: certest123f.yourdomain.com
  dnsNames:
  - certest123f.yourdomain.com
  - "*.yourdomain.com"
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
    group: cert-manager.io
```
 6. after few mins, check certificates `kubectl -n default describe certificate/yourdomain-tls` 

----

**Role mode for aliyun kubernetes service ACK**

ACK cluster already have role attached to worker nodes,you can get it from web console or apis

just attach policy to worker nodes role, and config `authmode: role` and `rolename: KubernetesWorkRole-xxxx` in issuer or clusterissuer object
```bash
aliyun ram AttachPolicyToRole --region cn-hangzhou --PolicyType System --PolicyName AliyunDNSFullAccess --RoleName KubernetesWorkerRole-xxxxx
```

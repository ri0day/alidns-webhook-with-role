# alidns-webhook-with-role
This repo basicly is an clone of [original repo](https://github.com/pragkent/alidns-webhook) ,except add support alicloud role authentication

## Why
if the cluster is already running on aliyun ,we can avoid pass plain text accesskey and secretkey to webhook configuration,which  reduce attack surfaces and forget about key rotation


## How
add `authmode` in webhook config field , expected  args:`ak`, `role`

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
4. create an clusterissuer
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
  name: example-tls
  namespace: default
spec:
  secretName: example-com-tls
  commonName: certest123f.example.com
  dnsNames:
  - certest123f.example.com
  - "*.example.com"
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
    group: cert-manager.io
```
 6. after few mins, check certificates `kubectl -n default describe certificate/example-tls` 

**Role mode Example for aliyun kubernetes service ACK**

ACK cluster already have role attached to worker nodes,you can get it from web console or api
just attch policy to worker nodes role, and config rolename  in clusterissuer
```bash
aliyun ram AttachPolicyToRole --region cn-hangzhou --PolicyType System --PolicyName AliyunDNSFullAccess --RoleName KubernetesWorkerRole-xxxxx
```

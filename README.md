# Bind9 Container for running DNS servers in Kubernetes

## Background

This image is intended to be used to run classical DNS servers in Kubernetes, it's not intended to replace or interact with kube-dns at all.

## Example usage

Create a config map for the named.conf file and zone files, this ensures that the server is stateless and any replicas will have the same configuration.  

Any updates to the zones will be pushed directly by kubernetes.

IMPORTANT: You want to create a acl for trusted networks, in this case it's a private network (192.168.0.0/24).  Without this your DNS server is open to the world and could be used in DNS reflection attacks.

```
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: named-conf
data:
  named.conf: |
    acl "trusted" {
        localhost;
        127.0.0.1;
        192.168.0.0/24;
    };
    logging {
       channel default_log {
         print-time yes;
         print-category yes;
         print-severity yes;
         syslog daemon;
         severity info;
       };
       category default { default_log; };
       category queries { default_log; };
    };
    options {
            directory "/var/cache/bind";
            allow-transfer { none; };
            recursion yes;
            allow-recursion { trusted; };
            allow-query { trusted; };
            forwarders {
              8.8.8.8;
              8.8.4.4;
            };
            dnssec-validation auto;
            listen-on-v6 { any; };
    };
    zone "my.zone.com" IN {
            type master;
            file "/etc/bind/db.my.zone.com";
    };
    zone "0.168.192.in-addr.arpa" {
            type master;
            file "/etc/bind/db.192.168.0";
    };
  db.my.zone.com: |
    $TTL    60
    @       IN      SOA     ns1.my.zone.com. root.my.zone.com. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
            IN      NS      ns1.my.zone.com. ;
    ; A records
    ns1.my.zone.com.         IN      A       192.168.2.1;
    mail                         IN      CNAME   gmail.com;
  db.192.168.0: |
    $TTL    60
    @       IN      SOA     my.zone.com. root.my.zone.com. (
                              3         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
            IN      NS      ns1.my.zone.com. ;
    ; A records
    2       IN      PTR     severx.my.zone.com. ;

```
Now we create the deployment, the configmap above is mounted as the configuration and the zone files.

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dns
  labels:
    app: dns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dns
  template:
    metadata:
      labels:
        app: dns
    spec:
      restartPolicy: Always
      containers:
      - name: dns
        image: garybowers/bind9:0.6
        ports:
        - containerPort: 53
          name: dns
        volumeMounts:
        - name: cfg-vol-named-conf
          mountPath: /etc/bind
      volumes:
        - name: cfg-vol-named-conf
          configMap:
            name: named-conf
```

Now we expose the DNS Server to the network.  We create a internal lodbalancer of the IP Address 192.168.0.1 to serve traffic to.

```
---
apiVersion: v1
kind: Service
metadata:
  name: int-dns-ilb
  annotations:
    cloud.google.com/load-balancer-type: "Internal"
  labels:
    app: dns
spec:
  type: LoadBalancer
  loadBalancerIP: 192.168.0.1
  ports:
    - name: udp-dns
      port: 53
      targetPort: 53
      protocol: UDP
  selector:
    app: dns
```
You can also expose to external but it's highly recommended to create loadbalancer rules to restrict who can contact the server.

```
---
apiVersion: v1
kind: Service
metadata:
  name: int-dns-elb
  labels:
    app: dns
spec:
  type: LoadBalancer
  loadBalancerSourceRanges:
  - xx.xx.xx.xx/xx  # Replace me with a real extenrnal CIDR.
  ports:
    - name: udp-dns
      port: 53
      targetPort: 53
      protocol: UDP
  selector:
    app: dns
```

apiVersion: v1
kind: Service
metadata:
  namespace: rpi3cameras
  name: zoneminder-rpi3cameras
  labels:
    app: zoneminder-rpi3cameras
spec:
  ports:
  - name: zoneminder-rpi3cameras
    protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
  selector:
    app: zoneminder-rpi3cameras
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: zoneminder-rpi3cameras
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: zoneminder-rpi3cameras
      namespace: rpi3cameras
    spec:
      containers:
      - name: zoneminder-rpi3cameras
#        image: thisistom/zm_server:v1.30.4
        image: thisistom/zm_server_s3_alarm:v1.30.4
        env:
        - name: DB_HOST
          value: "_DB_IP_:_DB_PORT_"
        - name: NFS_MOUNT_TYPE
          value: "nfs4"
        - name: NFS_MOUNT_OPTIONS
          value: "soft,intr,tcp,rw,port=_NFS_PORT_"
        - name: NFS_ZM_PATH 
          value: "_NFS_IP_:/"
        ports:
        - containerPort: 80
        securityContext:
          privileged: true
      nodeSelector:
        kubernetes.io/hostname: monarch.delimitize.com

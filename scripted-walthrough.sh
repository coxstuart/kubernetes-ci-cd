#!/bin/bash
# Type sh part1.sh to execute

echo
echo --------------------------------------------------------------------
echo BRING UP MINIKUBE WITH ADDONS
echo --------------------------------------------------------------------
echo 1.  Start up the Kubernetes cluster with Minikube, giving it some extra resources
echo 2.  Enable the Minikube add-ons Heapster and Ingress
echo --------------------------------------------------------------------
sh minikube_reset.sh
minikube start --memory 8000 --cpus 2
minikube addons enable heapster; minikube addons enable ingress


#Skipping these
#echo
#echo --------------------------------------------------------------------
#echo DEPLOY NGINX TEST POD
#echo --------------------------------------------------------------------
#echo 1. Deploy the public nginx image into a pod. Nginx is an open source web server that will automatically download from Docker Hub if it’s not available locally.
#echo 2. Create a K8s Service for the deployment. This will expose the nginx pod so you can access it with a web browser.
#echo 3. Launch a web browser to test the service. The nginx welcome page displays, which means the service is up and running.
#echo 4. Delete the nginx deployment and service we created.""
#echo --------------------------------------------------------------------
#kubectl run nginx --image nginx --port 80
#kubectl expose deployment nginx --type NodePort --port 80
#inikube service nginx
#kubectl delete service nginx; kubectl delete deployment nginx

echo
echo --------------------------------------------------------------------
echo DEPLOY LOCAL CLUSTER REGISTRY
echo --------------------------------------------------------------------
echo 3.  Set up the cluster registry on minikube by applying a .yaml manifest file
echo 4.  Wait for the registry to finish deploying. 
echo     Note that this may take several minutes
echo 5.  View the registry user interface in a web browser
echo --------------------------------------------------------------------
kubectl apply -f manifests/registry.yaml
kubectl rollout status deployments/registry
minikube service registry-ui

echo
echo --------------------------------------------------------------------
echo MODIFY NGNIX DEPLOYMENT
echo --------------------------------------------------------------------
echo 6.  Now, let’s make a change to an HTML file in the cloned project.
echo     Open the /applications/hello-kenzan/index.html file, make changes, amd save. 
echo ----------------------------------
read -p "Press [Enter] key after your changes have been made"

echo
echo --------------------------------------------------------------------
echo BUILD AND DEPLOY IMAGE USING PROXY
echo --------------------------------------------------------------------
echo 7.  Now let’s build an image, giving it a special name that points to our local cluster registry.
echo 8.  Before we can push it to the registry, we need to set up a temporary proxy. 
echo     By default the Docker client can only push to HTTP via localhost. 
echo     To work around this, we set up a Docker container that listens on 127.0.0.1:30400.
echo     Requests are forwarded over HTTPS to our cluster. 
echo 9.  Build the a socat image for our proxy container.
echo 10. Run the proxy container from the newly created image. 
echo     Note that you may see some errors.  This is normal.
echo     Errors are on commands are first making sure there are no previous instances running.
echo 11. With our proxy container up and running, we can push our hello-kenzan image to the repo.
echo 12. After the proxy’s work is done, so we can go ahead and stop it.
echo 13. With the image in our registry, we can apply the manifest to deploy the hello-kenzan pod.
echo 14. Finally, launch a web browser and view the service
echo --------------------------------------------------------------------
docker build -t 127.0.0.1:30400/hello-kenzan:latest -f applications/hello-kenzan/Dockerfile applications/hello-kenzan
docker build -t socat-registry -f applications/socat/Dockerfile applications/socat
docker stop socat-registry; docker rm socat-registry; 
docker run -d -e "REG_IP=`minikube ip`" -e "REG_PORT=30400" --name socat-registry -p 30400:5000 socat-registry
docker push 127.0.0.1:30400/hello-kenzan:latest
docker stop socat-registry;
kubectl apply -f applications/hello-kenzan/k8s/manual-deployment.yaml
minikube service hello-kenzan

echo
echo --------------------------------------------------------------------
echo BUILD AND DEPLOY JENKINS CONTAINER 
echo --------------------------------------------------------------------
echo 15. Now we will build a Jenkins docker container from image.
echo 16. Run the socat-registry proxy locally so that we can push the Jenkins image to private regisry without https
echo 17. With our proxy container up and running, push the Jenkins image to the repo.
echo 18. After the proxy’s work is done, so we can go ahead and stop it.
echo 19. With the image in our registry, we can apply the Jenkins manifest to deploy the Jenkins pod.
echo 20. Finally, launch a web browser and view the Jenkins UI
echo --------------------------------------------------------------------
docker build -t 127.0.0.1:30400/jenkins:latest -f applications/jenkins/Dockerfile applications/jenkins
docker run -d -e "REG_IP=`minikube ip`" -e "REG_PORT=30400" --name socat-registry -p 30400:5000 socat-registry
docker start socat-registry
docker push 127.0.0.1:30400/jenkins:latest
docker stop socat-registry
kubectl apply -f manifests/jenkins.yaml; kubectl rollout status deployment/jenkins
kubectl get pods
minikube service jenkins

echo
echo --------------------------------------------------------------------
echo CONFIGURE JENKINS
echo --------------------------------------------------------------------
echo 21. Get initial Jenkins admin password, from kubectl used to login
echo 22. Log in to Jenkins as admin
echo 23. Take UI prompt to install recommended plug-ins
echo 24. Set administrator credentials as JenkinsAdmin / jenkins
echo 25. Save jenkins url for absolute links / resources: http://192.168.99.116:31472/
echo 26. Take UI option to Restart jenkins
echo 27. Add Jenkins store credentials
echo     Navigate System - Global credentials (unrestricted), click link to add credentials
echo     Kind: Kubernetes configuration (kubeconfig)
echo     ID: kenzan_kubeconfig
echo     Kubeconfig:  From a file for Jenkins master
echo     File: /var/jenkins_home/.kube/config
echo 28. Add new item Hello-Kenzan Pipeline
echo     Add New Item
echo     Name: Hello-Kenzan Pipeline
echo     Type: Pipeline
cho      Select Type: Pipeline and clik OK
echo         Under Pipeline, seltect Pipeline script from SCM
echo         Select SCM: Git
echo         Enter repository url
echo         Click Save
echo --------------------------------------------------------------------
kubectl exec -it `kubectl get pods --selector=app=jenkins --output=jsonpath={.items..metadata.name}` cat /var/jenkins_home/secrets/initialAdminPassword
read -p "Press [Enter] key after your pipeline has ben setup"

echo
echo --------------------------------------------------------------------
echo TEST AND TROUBLESHOOT PIPELINE 
echo --------------------------------------------------------------------
echo 22. Click Build Now to test build
echo 23. If build fails on deployment, you may need to reset minikube ip
echo     minikube ip command should return 192.168.99.100
echo     If not, you will have to stop, RESET, and restart minikube to reset the ip
echo     minikube stop
echo     sh minikube_reset.sh
echo     minikube start --memory 8000 --cpus 2
read -p "Press [Enter] key after build is succesfully deployed"
echo --------------------------------------------------------------------

echo
echo --------------------------------------------------------------------
echo PIPELINE IN ACTION
echo --------------------------------------------------------------------
echo 24. Modify index.html, commit and push change
echo 25. Click Build Now on Jenkins pipeline
echo 26. View pods to see new pods deployed
echo     kubectl get pods -o wide
echo     NOTE: To get this working, had to use a specific tag (:dev) in Jenkinsfile and deployment.yaml
read -p "Press [Enter] key after updated build is succesfully deployed"

echo
echo --------------------------------------------------------------------
echo 27. INITIALIZE HELM AND TILLER ON THE CLUSTER
echo --------------------------------------------------------------------
helm init --wait --debug
kubectl rollout status deploy/tiller-deploy -n kube-system

echo
echo --------------------------------------------------------------------
echo 28. DEPLOY ETCD OPERATOR INTO CLUSTER USING PULIC HELM CHART
echo     Note: This is used for crossword data, not same and k8s etcd instance
echo --------------------------------------------------------------------
helm install stable/etcd-operator --version 0.8.0 --name etcd-operator --debug --wait
kubectl create -f manifests/etcd-cluster.yaml
kubectl create -f manifests/etcd-service.yaml

echo
echo --------------------------------------------------------------------
echo 29. DEPLOY MANIFEST TO APPLY ALL THREE APPS
echo --------------------------------------------------------------------
kubectl apply -f manifests/all-services.yaml

echo
echo --------------------------------------------------------------------
echo 30. BUILD AND DEPLOY MONITOR-SCALE APP
echo --------------------------------------------------------------------
docker build -t 127.0.0.1:30400/monitor-scale:`git rev-parse --short HEAD` -f applications/monitor-scale/Dockerfile applications/monitor-scale
docker stop socat-registry;docker rm socat-registry; 
docker run -d -e "REG_IP=`minikube ip`" -e "REG_PORT=30400" --name socat-registry -p 30400:5000 socat-registry
docker push 127.0.0.1:30400/monitor-scale:`git rev-parse --short HEAD`
docker stop socat-registry
minikube service registry-ui
read -p "Press [Enter] key after imaage is available in private registry"


echo
echo --------------------------------------------------------------------
echo 31. APPLY RBAC SERVICE ACCOUNTS
echo --------------------------------------------------------------------
kubectl apply -f manifests/monitor-scale-serviceaccount.yaml

echo
echo --------------------------------------------------------------------
echo CREATE MONITOR-SCALE DEPLOYMENT INGRESS
echo --------------------------------------------------------------------
echo 32. sed command is replacing $BUILD_TAG subtring in manifest file with the actual build tag value
echo 33. Wait for minotor-scale deployment to finish
echo --------------------------------------------------------------------
sed 's#127.0.0.1:30400/monitor-scale:$BUILD_TAG#127.0.0.1:30400/monitor-scale:'`git rev-parse --short HEAD`'#' applications/monitor-scale/k8s/deployment.yaml | kubectl apply -f -
kubectl rollout status deployment/monitor-scale
kubectl get pods
kubectl get services
kubectl get ingress
kubeclt get deployments

echo
echo --------------------------------------------------------------------
echo BOOTSTRATP PUZZLE AND MONGO SERVICES
echo --------------------------------------------------------------------
echo 34. Run scripts/puzzle.sh to roll out other services
echo 35. Check status of mongo and puzzle deployment
echo --------------------------------------------------------------------
scripts/puzzle.sh
kubectl rollout status deployment/puzzle; kubectl rollout status deployment/mongo;


echo
echo --------------------------------------------------------------------
echo BOOTSTRATP KR8SSWRODZ FRONT-END UI
echo --------------------------------------------------------------------
echo 36. Run scripts/kr8sswordz-pages.sh to roll out ui
echo 37. Check status of mongo and puzzle deployment
echo 28. Start the web UI n browser
echo --------------------------------------------------------------------
scripts/kr8sswordz-pages.sh
kubectl rollout status deployment/kr8sswordz
kubectl get pods
kubectl get services
kubectl get ingress
kubeclt get deployments
minikube service kr8sswordz


#echo
#echo --------------------------------------------------------------------
#echo OPEN THE MINIKUBE DASHBOARD
#echo PRESS CTRL-Z TO QUIT!
#echo --------------------------------------------------------------------
#echo Open the minikube dashboard
#echo --------------------------------------------------------------------
#minikube dashboard

#echo
#echo --------------------------------------------------------------------
#echo TAKE IT DOWN
#echo --------------------------------------------------------------------
#echo Delete the hello-kenzan deployment and service.
#echo Shut down minikube and delete minikube cluster.
#echo --------------------------------------------------------------------
#kubectl delete service hello-kenzan; kubectl delete deployment hello-kenzan; 
#minikube stop;  
#sh minikube_reset.sh
#minikube delete;
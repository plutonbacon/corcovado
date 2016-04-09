.PHONY: all

# Misc
DEVNULL=2>&1 > /dev/null
APTUPDATE=sudo apt-get update -y
APTINSTALL=sudo apt-get install -y 
UBUNTU_RELEASE=trusty
CRLF=echo ""

# Kubernetes-related
KCREATE=kubectl create
KDELETE=kubectl delete
KGET=kubectl get
KSVCS=kubectl get services

# Ceph-related
CEPH_RELEASE=hammer

# Components
LOGS=logging

all:
	@$(CRLF)
	@echo "###################################################################"
	@echo "#                      CORCOVADO - v0.1.0.dev                     #"
	@echo "#                                                                 #"
	@echo "#                     - https://corcovado.io -                    #"
	@echo "###################################################################"
	@$(CRLF)
	@echo "Available targets:"
	@echo "  *  run-preflight  - prep your environment"
	@echo "  *  deploy-logging - deploy a ceph distributed filesystem"
	@echo "  *  deploy-storage - deploy an elk cluster for centralized logging"

run-preflight:
	@$(CRLF)
	@echo "Running pre-flight tasks ..."
	@echo "   -- Installing prepackaged dependencies"
	@sudo ln -fs /usr/share/zoneinfo/UTC /etc/localtime $(DEVNULL);
	@echo "     [x] timezone set to UTC";
	@$(APTINSTALL) ntp $(DEVNULL);
	@echo "     [x] ntp client installed";
	@sudo cp preflight/ntp.conf /etc/ntp.conf $(DEVNULL);
	@sudo /etc/init.d/ntp stop $(DEVNULL);
	@sudo ntpdate -s 0.north-america.pool.ntp.org $(DEVNULL);
	@sudo /etc/init.d/ntp start $(DEVNULL);
	@echo "     [x] time synced with 0.north-america.pool.ntp.org";
	@$(APTINSTALL) git $(DEVNULL);
	@echo "     [x] git client installed";

deploy-storage:
	@$(CRLF)
	@echo "Deploying an Ceph cluster ..."
	
	@$(CRLF)
	@echo "   -- Configuring apt"
	@wget -q -O- https://download.ceph.com/keys/release.asc | sudo apt-key add - | grep --quiet OK;	\
	status=$$?;											\
	if [ $$status = 0 ];										\
	then echo "     [x] ceph release key added";							\
	else echo "     [!] failed to add the ceph release key";					\
	fi 2>&1 
	
	@echo deb http://download.ceph.com/debian-$(CEPH_RELEASE)/ $(UBUNTU_RELEASE) main | sudo tee /etc/apt/sources.list.d/ceph.list $(DEVNULL);
	@echo "     [x] ceph repo added to apt sources";

	@$(APTUPDATE) $(DEVNULL);
	@echo "     [x] re-synchronized package sources";

	@$(APTINSTALL) ceph-deploy $(DEVNULL);
	@echo "     [x] ceph-deploy installed";


deploy-logging:
	@$(CRLF)
	@echo "Deploying an ELK cluster to centralize logging ..."
	
	@$(CRLF)
	@echo "   -- Creating service accounts"
	@$(KGET) serviceaccounts/elasticsearch -o yaml 2>&1 | grep --quiet Error;										\
	status=$$?; 																		\
	if [ $$status = 0 ]; 																	\
	then $(KCREATE) -f $(LOGS)/es-svc-account.yaml $(DEVNULL); echo "      [x] elasticsearch created";							\
	else $(KDELETE) serviceaccounts/elasticsearch $(DEVNULL); $(KCREATE) -f $(LOGS)/es-svc-account.yaml $(DEVNULL); echo "     [x] elasticsearch created"; 	\
	fi 2>&1
	
	@$(CRLF)
	@echo "   -- Creating services"
	@$(KSVCS) | grep --quiet elasticsearch-discovery;															\
	status=$$?;																				\
	if [ $$status = 1 ];																			\
	then $(KCREATE) -f $(LOGS)/es-discovery-svc.yaml $(DEVNULL); echo "     [x] elasticsearch-discovery created";								\
	else $(KDELETE) -f $(LOGS)/es-discovery-svc.yaml $(DEVNULL); $(KCREATE) -f $(LOGS)/es-discovery-svc.yaml $(DEVNULL); echo "     [x] elasticsearch-discovery created";	\
	fi 2>&1

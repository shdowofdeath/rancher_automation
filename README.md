# rancher_automation

### pre req :)
docker install doesn't mettter what OS or what docker version  



### for example install docker in ubuntu :) 16.04 and latest 
    sudo apt-get -y update 
    sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo apt-key fingerprint 0EBFCD88 
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get -y update
    sudo apt-get install -y docker-ce python python3-pip

    
### for example install docker in aws ami :) 
    sudo yum update -y
    sudo yum install amazon-linux-extras install -y docker
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    yum install -y git python python-pip

### Steps to deploy :) 3 min and you there :)


    git clone https://github.com/shdowofdeath/rancher_automation.git

    cd rancher_automation

    bash rancher_install


open issue in-case of issue 
https://github.com/shdowofdeath/rancher_automation/issues/new 


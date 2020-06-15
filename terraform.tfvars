#---------------------------------------------------------
# MODIFY VARIABLES AS NEEDED
#---------------------------------------------------------

#---------------------------------------------------------
## VPC
#---------------------------------------------------------

vpc_name = "tf-test-fss"
resource_group = "default"
region = "us-south"

#---------------------------------------------------------
security_group_rules = {
    ssh = {
      security_group = "custom-image-sg-fss"
      direction = "inbound"
      remote = "0.0.0.0/0"
      ip_version = ""
      icmp = []
      tcp = [
        {
          port_min = 22
          port_max = 22
        }
      ]
      udp = []
    },
    ssh_outbound = {
      security_group = "custom-image-sg-fss"
      direction = "outbound"
      remote = "0.0.0.0/0"
      ip_version = ""
      icmp = []
      tcp = []
      udp = []
    }
  }

#---------------------------------------------------------
## SSH Keys
#---------------------------------------------------------
ssh_keys = [
  {
     name = "jeffrey-hoekman"
  }
]

#---------------------------------------------------------
## Address Prefixes
#---------------------------------------------------------
address_prefixes = {
     zone1-cidr-1 = {
       zone_name = "us-south-1"
       cidr = "172.21.0.0/21"
     }
  }

#---------------------------------------------------------
## Subnets
#---------------------------------------------------------
subnets = {
    us-south-1-subnet-fss = {
      zone = "us-south-1"
      cidr_block = "172.21.0.0/24"
      public_gateway = ""
    }
  }

#---------------------------------------------------------
## Cloud init user data
#---------------------------------------------------------
cloud_init_data = {
     user_data = {
       base64_encode = false
       gzip = false
       content = <<EOF
    #cloud-config
    package_update: true
    package_upgrade: true
    write_files:
      - content: |
          HELLO WORLD
        path: /root/message
    runcmd:
      # install terraform
      - 'curl -sL https://ibm.biz/idt-installer | bash -s -- --trace'
      - 'wget https://releases.hashicorp.com/terraform/0.12.26/terraform_0.12.26_linux_amd64.zip'
      - 'unzip ./terraform_0.12.26_linux_amd64.zip'
      - 'chmod +x terraform && mv terraform /usr/local/bin/'
      - 'terraform –v'
      - 'ls -alh /root'
      # install IBM cloud terraform provider plugin
      - 'wget https://github.com/IBM-Cloud/terraform-provider-ibm/releases/download/v1.7.1/linux_amd64.zip'
      - 'unzip linux_amd64.zip'
      - 'mkdir -p mkdir /root/.terraform.d/plugins'
      - 'mv terraform-provider-ibm_v1.7.1 /root/.terraform.d/plugins'
      - 'ls -alh /root/.terraform.d/plugins'

#      - sed -i -e '/^Port/s/^.*$/Port 4444/' /etc/ssh/sshd_config
#      - restart ssh
    packages:
      - htop
      - unzip
    EOF
    }
  }

#---------------------------------------------------------
## Servers
#---------------------------------------------------------
   servers = [
     {
       count = 1
       name = "fss-server"
       # ibm-ubuntu-18-04-1-minimal-amd64-1
       image = "r006-14140f94-fcc4-11e9-96e7-a72723715315"
       profile = "bx2-4x16"
       subnet = "us-south-1-subnet-fss"
       zone = "us-south-1"
       ssh_key_list = ["jeffrey-hoekman"]
       network_interfaces = {}
       security_groups = ["custom-image-sg-fss"]
       volumes = []
       user_data = "user_data"
     }
   ]

floating_ips = ["fss-server-0"]


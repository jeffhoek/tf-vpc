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
## Servers
#---------------------------------------------------------
   servers = [
     {
       count = 1
       name = "fss-server"
       image = "04f4c424-a90d-4c2b-a77f-db67ff9b1629"
       profile = "bx2-4x16"
       subnet = "us-south-1-subnet-fss"
       zone = "us-south-1"
       ssh_key_list = ["jeffrey-hoekman"]
       network_interfaces = {}
       security_groups = ["custom-image-sg-fss"]
       volumes = []
       user_data = ""
     }
   ]

floating_ips = ["fss-server-0"]


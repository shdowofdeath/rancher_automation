import requests, os, sys, argparse


def get_args():
    """
    getting all args from user
    :return: all parms
    """
    parser = argparse.ArgumentParser(
        description='Script retrieves create file for authentication k8s localy')
    parser.add_argument(
        '-u', '--username', type=str, help='Username to access k8s deployment', required=True)
    parser.add_argument(
        '-p', '--password', type=str, help='Password to access k8s deployment', required=True)
    parser.add_argument(
        '-i', '--master_ip', type=str, help='IP to access k8s deployment', required=True)
    parser.add_argument(
        '-o', '--port', type=str, help='port to access k8s deployment', required=True)
    parser.add_argument(
        '-c', '--cluster_name', type=str, help='Cluster name  to access k8s deployment', default='local',
        required=False)
    parser.add_argument(
        '-d', '--debug', type=str, help='debug mode', default=False, required=False)
    parser.add_argument(
        '-s', '--set_proxy', type=str, help='set proxy mode', default=True, required=False)
    args = parser.parse_args()
    username = args.username
    password = args.password
    master_ip = args.master_ip
    cluster_name = args.cluster_name
    debug = args.debug
    port = args.port
    set_proxy = args.set_proxy
    global home
    home = os.environ['HOME']
    get_cred(username, password, master_ip, debug, cluster_name, port, set_proxy)


def get_cred(username, password, master_ip, debug, cluster_name, port, set_proxy):
    """
    :param username: it's the user name for connecting k8s
    :param password: it's the password for connecting k8s
    :param master_ip: the master/s ip/s that we need to take cred from
    :param debug: if you want to see debug output
    :param cluster_name: the default cluster name
    :param port: k8s port
    :return: token for accessing the cluster
    """
    os.environ['NO_PROXY'] = master_ip
    url = "https://" + master_ip + ":" + port + "/v3-public/localProviders/" + cluster_name
    querystring = {"action": "login"}
    payload = "{ \"username\" : \"%s\" ," "\"password\" : \"%s\" }" % (username, password)
    headers = {
        'Content-Type': "application/json",
        'Accept': "application/json",
        'Cache-Control': "no-cache"
    }
    if debug:
        print(username, password)
        print(url)
    try:
        access = requests.request("GET", url, data=payload, verify=False)
    except:
        print("cannot access the cluster check ip please ", master_ip)
        sys.exit(1)
    response = requests.request("POST", url, data=payload, headers=headers, params=querystring, verify=False)
    token_rancher = response.json()
    token = token_rancher['token']
    create_cred_file(token, debug, port, master_ip)




def create_cred_file(token, debug, port, master_ip):
    """
    creating file for k8s contex
    :param token: to access k8s
    :param master_ip: the master/s ip/s that we need to take cred from
    :param debug: if you want to see debug output
    :param port: k8s port
    :return: file path
    """
    if token != None:
        url = "https://" + master_ip + ":" + port + "/v3/clusters/local"
        querystring = {"action": "generateKubeconfig"}
        payload = "\r\n}\r\n}"
        headers = {
            'Content-Type': "application/json",
            'Accept': "application/json",
            'Authorization': "Bearer " + token,
            'Cache-Control': "no-cache"
        }
        response = requests.request("POST", url, data=payload, headers=headers, params=querystring, verify=False)
        response_parsed = response.json()
        making_yaml = response_parsed['config']
        if making_yaml != None:
            directory = home + '/.kube/'
            file = directory + 'config'
            if not os.path.exists(directory):
                os.makedirs(directory)
            with open(file, 'a') as the_file:
                the_file.truncate(0)
                the_file.write(making_yaml)
            if debug:
                with open(file, 'r') as the_file:
                    print(the_file.read())
            print("finish to create kubectl file in:", file, "path")
        else:
            print("can't find data yaml file ")
    else:
        print("cannot validate token")


get_args()


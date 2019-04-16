import os
import sys
import argparse
import getpass
import requests

from time import sleep
from requests import exceptions as requests_exceptions
from lxml import etree, objectify

PY3 = sys.version_info[0] == 3

if PY3:
    from urllib import parse as urlparse
else:
    import urlparse
    
HOPSWORKS_SERVICE_LOGIN = "hopsworks-api/api/auth/service"
HEADERS = {'Content-Type': 'application/x-www-form-urlencoded',
           'User-Agent': 'service_renew_py'}
AUTH_HEADER = "Authorization"

MASTER_TOKEN_PROPERTY = "yarn.resourcemanager.rmappsecurity.jwt.master-token"
RENEW_TOKENS_PROPERTY_TEMPLATE = "yarn.resourcemanager.rmappsecurity.jwt.renew-token-{0}"

def login(username, password, host):
    print("Login to: " + host)
    with requests.Session() as session:
        login_payload = {"email": username, "password": password}
        url = "https://{host}/{endpoint}".format(host=host, endpoint=HOPSWORKS_SERVICE_LOGIN)
        
        attempts = 1
        while True:
            try:
                response = session.post(url, headers=HEADERS, data=login_payload, verify=False)
                response.raise_for_status()
                j_response = response.json()

                if AUTH_HEADER not in response.headers:
                    raise Exception("Response does not contain \'" + AUTH_HEADER + "\' header")
                bearer = response.headers[AUTH_HEADER]

                master_token = bearer.split()[1].strip()
                return master_token, j_response['renewTokens']
            except requests_exceptions.SSLError as ex:
                print("SSLError, will not retry")
                raise ex
            except requests_exceptions.RequestException as ex:
                if ex.response.status_code / 4 == 100:
                    raise ex
                if attempts > 3:
                    print("Tried " + str(attempts) + " times. Giving up...")
                    raise ex
                print("Error trying to login. Retry in 1 second")
                attempts += 1
                sleep(1)
        
def config_path():
    self_path = os.path.dirname(sys.argv[0])
    if not self_path:
        self_path = "."
    return os.path.join(self_path, "..", "etc", "hadoop", "ssl-server.xml")

def replace_tokens(master_token, renew_tokens, file_path):
    with open(file_path, 'r') as rfd:
        xml = rfd.read()
    root = objectify.fromstring(xml)

    for prop in root.getchildren():
        if prop.name == MASTER_TOKEN_PROPERTY:
            print("Found master token property: " + MASTER_TOKEN_PROPERTY)
            prop.value = master_token

    renew_tokens_size = len(renew_tokens)
    for i in range(0, len(renew_tokens)):
        for prop in root.getchildren():
            property_name = RENEW_TOKENS_PROPERTY_TEMPLATE.format(i)
            if prop.name == property_name:
                print("Found renew token property: " + property_name)
                prop.value = renew_tokens[i]

            
    objectify.deannotate(root)
    etree.cleanup_namespaces(root)
    obj_xml = etree.tostring(root,
                             pretty_print=True,
                             xml_declaration=True)
    with open(file_path, 'w') as wfd:
        wfd.write(obj_xml)

# Remove protocol
def parse_host(args_host):
    parsed_host = urlparse.urlparse(args_host).hostname
    # Host from arguments contains protocol
    if parsed_host:
        port = urlparse.urlparse(args_host).port
        if not port:
            port = "443"
        return "{0}:{1}".format(parsed_host, port)
    return args_host

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Force replace service JWT")
    parser.add_argument('--host', required=True, help="Hopsworks host")
    parser.add_argument('-u', '--user', required=True, help="Service username")
    parser.add_argument('-p', '--password', help="Password to login")
    parser.add_argument('-f', '--file', help="Path to ssl-server.xml")
    args = parser.parse_args()
    if not args.password:
        user_password = getpass.getpass("Password:")
    else:
        user_password = args.password

    master_token, renew_tokens = login(args.user, user_password, parse_host(args.host))
    if not args.file:
        file_path = config_path()
    else:
        file_path = args.file
    replace_tokens(master_token, renew_tokens, file_path)

from googleapiclient import discovery
import os
import time
import json
import hashlib

project_id = os.environ.get('_PROJECT_ID', 'Environment variable does not exist')
gcp_region = os.environ.get('_GCP_REGION', 'Environment variable does not exist')
cs_job_id = os.environ.get('_CS_JOB_ID', 'Environment variable does not exist')

CHUNK_SIZE=int(os.environ.get('_CHUNK_SIZE', 'Environment variable does not exist'))
target_https_proxy = os.environ.get('_TARGET_HTTPS_PROXY', 'Environment variable does not exist')
new_domain_list = os.environ.get('_NEW_DOMAIN_LIST', 'Environment variable does not exist')
new_certs_list = os.environ.get('_NEW_CERTS_LIST', 'Environment variable does not exist')
fixed_certs_list = os.environ.get('_FIXED_CERTS_LIST', 'Environment variable does not exist')

new_domain_list = new_domain_list.split(",")
new_certs_list = new_certs_list.split(",")
fixed_certs_list = fixed_certs_list.split(",")

# Split domain list for multiple certificates (since there is a maximun number of domains per certificate)
chunked_domain_list = [new_domain_list[x:x+CHUNK_SIZE] for x in range(0, len(new_domain_list), CHUNK_SIZE)]

service = discovery.build('compute', 'v1')

def get_current_certs():
	request = service.targetHttpsProxies().get(project=project_id, targetHttpsProxy=target_https_proxy)
	response = request.execute()
	current_certs_list = [cert.split("/")[9] for cert in response["sslCertificates"]]
	return current_certs_list

def create_new_certs():
	UPDATE_NEW_CERTS = 0
	current_certs_list = get_current_certs()
	for index, cert in enumerate(new_certs_list):
		if cert not in current_certs_list :
			print("Creating the new SSL certificate..")
			ssl_certificate_body = {
				"name" : cert,
    				"managed" : {
						"domains" : chunked_domain_list[index]
					},
				"type" : "MANAGED"
			}
			request = service.sslCertificates().insert(project=project_id, body=ssl_certificate_body)
			request.execute()
			# Wait for target proxy to be ready
			time.sleep(5)
			UPDATE_NEW_CERTS = 1
		else:
			print("Certificates already exists")

	all_certs_list = [*current_certs_list, *new_certs_list]
	if UPDATE_NEW_CERTS == 1:
		print("Adding new certificates to target proxies to validate them..")
		target_https_proxies_set_ssl_certificates_request_body = {
			"sslCertificates": ["projects/{project_id}/global/sslCertificates/{cert}".format(
				project_id=project_id,cert=c) for c in all_certs_list]
		}
		request = service.targetHttpsProxies().setSslCertificates(project=project_id, targetHttpsProxy=target_https_proxy, 
			body=target_https_proxies_set_ssl_certificates_request_body)
		request.execute()
	else:
		print("Certificates already added to target proxy...")


def update_proxy():

	NEW_CERTS_ACTIVE = 1

	old_certs_list = get_current_certs()
	old_certs_list = [cert for cert in old_certs_list if cert not in fixed_certs_list and cert not in new_certs_list]

	for cert in new_certs_list:
		request = service.sslCertificates().get(project=project_id, sslCertificate=cert)
		response = request.execute()
		if response["managed"]["status"] != "ACTIVE":
			NEW_CERTS_ACTIVE = 0

	# Exit if new certificates all still provisioning
	if NEW_CERTS_ACTIVE == 0:
		print("Some new certs are still provisioning...")
		return False

	# If all new certificates are active rotate them on target proxy
	updated_certs_list = [*fixed_certs_list, *new_certs_list]
	target_https_proxies_set_ssl_certificates_request_body = {
		"sslCertificates": ["projects/{project_id}/global/sslCertificates/{cert}".format(
			project_id=project_id,cert=c) for c in updated_certs_list]
	}
	request = service.targetHttpsProxies().setSslCertificates(project=project_id, targetHttpsProxy=target_https_proxy, 
		body=target_https_proxies_set_ssl_certificates_request_body)
	request.execute()

	# Wait for target proxy to be ready
	time.sleep(10)
	
	# Finally delete old certificates
	for cert in old_certs_list:
		request = service.sslCertificates().delete(project=project_id, sslCertificate=cert)
		request.execute()
		print("Deleted old certificate..")

	return True


def pause_cloud_scheduler():
	service = discovery.build('cloudscheduler', 'v1')
	cs_job = "projects/{project_id}/locations/{gcp_region}/jobs/{job_id}".format(
			project_id=project_id, gcp_region=gcp_region, job_id=cs_job_id)

	pause_job_request_body = {}
	request = service.projects().locations().jobs().pause(name=cs_job, body=pause_job_request_body)
	request.execute()
	print("Paused cloud scheduler job..")


def rotate_certs(request):
	create_new_certs()
	if update_proxy():
		print("Certificate rotated.. pausing Cloud Scheduler job..")
		pause_cloud_scheduler()
	else:
		print("Certificates not rotated..")

	return "All done.."
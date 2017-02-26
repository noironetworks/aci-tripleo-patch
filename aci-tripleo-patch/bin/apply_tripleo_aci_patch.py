#!/usr/bin/env python

from __future__ import with_statement
import re, pdb

import os,sys,time,shutil,glob,shlex, subprocess


patch_dir = "/home/stack/aci_patch"
tripleo_patch_dir = "/opt/aci-tripleo-patch"
patched_images_dir = os.path.join(patch_dir, 'images')
base_rpm_list = glob.glob("%s/*.rpm" % tripleo_patch_dir)
opflex_rpm_list = glob.glob("%s/*.rpm" % patch_dir)

def local_cmd(cmd, cwd=None):
    print "Executing: %s" % cmd
    a1 = shlex.split(str(cmd))
    if cwd:
       p = subprocess.Popen(a1, stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=cwd)
    else:
       p = subprocess.Popen(a1, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    o, e = p.communicate()
    print o
    if p.returncode:
	print e
	sys.exit(p.returncode)
    return o


if not opflex_rpm_list:
    print "No RPMs found under %s, please download ACI rpm's from CCO to %s dir" % (patch_dir, patch_dir)
    sys.exit(1)

sortkeylist = ['python-inotify-', 'python-meld3-', 'supervisor-', 'python-click-', 'apicapi-' , 'boost-atomic-',
	'boost-chrono-', 'boost-context-', 'boost-date-time-', 'boost-filesystem-', 'boost-regex-',
	'boost-graph-', 'boost-iostreams-', 'boost-locale-', 'boost-math-', 'boost-python-', 'boost-random-',
	'boost-serialization-', 'boost-signals-', 'boost-test-', 'boost-thread-', 'boost-timer-', 'boost-wave-',
	'boost-[0-9]+', 'lldpd-', 'c-ares-', 'libev-', 'python2-tabulate-', 'python-websocket-client-', 'python-gevent-',
        'libuv-', 'libopflex-', 'libmodelgbp-', 'openvswitch-gbp-lib-', 'agent-ovs-',
	'neutron-opflex-agent-', 'neutron-ml2-driver-apic-', 'openstack-neutron-gbp-', 'python-gbpclient-',
	'python-django-horizon-gbp-', 'openstack-dashboard-gbp-', 'openstack-heat-gbp-', 'acitoolkit-', 'aci-integration-module-']
otherlist = ['ncclient-', 'neutron-dvs-agent-', 'python-UcsSdk-', 'python-networking-cisco-']

sortedlist = []
for key in sortkeylist:
    rex = re.compile("(^%s.*)" % key)
    sortedlist.append([l for l in base_rpm_list+opflex_rpm_list for m in [rex.search(os.path.basename(l))] if m][0])

olist = []
for key in otherlist:
    rex = re.compile("(^%s.*)" % key)
    olist.append([l for l in base_rpm_list+opflex_rpm_list for m in [rex.search(os.path.basename(l))] if m][0])

#check that images directory exists and has the necessary images
images_list = ['ironic-python-agent.initramfs', 'ironic-python-agent.kernel', 'overcloud-full.initrd', 'overcloud-full.qcow2', 'overcloud-full.vmlinuz']
for im in images_list:
    if not os.path.isfile(os.path.join('/home/stack', 'images', im)):
	print "Cannot find file %s under /home/stack/images" % im
	sys.exit(1)

#create a aci_patch/images directory
try:
    os.makedirs(patched_images_dir)
except:
    if not os.path.isdir(patched_images_dir):
	print "Error creating %s dir" % patched_images_dir

#copy the original images from /home/stack/images to /home/stack/images/aci_patch/images dir
print "Copying images to patch dir"
for im in images_list:
    shutil.copy(os.path.join('/home/stack/images', im), patched_images_dir)

#patch the overcloud image

img_path = os.path.join(patch_dir, "images", "overcloud-full.qcow2")
local_cmd("tar cf apic_gbp.tar -C %s  apic_gbp" % tripleo_patch_dir, cwd=patch_dir)
local_cmd("tar cf neutron.tar -C %s neutron" % tripleo_patch_dir, cwd=patch_dir)

cmd = "virt-customize -a %s --upload apic_gbp.tar:/root/apic_gbp.tar --upload neutron.tar:/root/neutron.tar" % img_path

#cmd = cmd + " --upload mypuppet:/var/lib/heat-config/hooks/puppet "
#cmd = cmd + " --firstboot-command \"adduser test -p cN.aVzmFELPKQ\" "
#cmd = cmd + " --firstboot-command \" echo 'test ALL=(root) NOPASSWD:ALL' | tee -a /etc/sudoers.d/stack \" "
#cmd = cmd + " --firstboot-command \" chmod 0440 /etc/sudoers.d/stack \""
cmd = cmd + " --firstboot-command \" yum -y remove python-networking-cisco \""
for f in sortedlist:
   cmd = cmd + " --upload %s:/root/%s" % (f, os.path.basename(f))
for f in olist:
   cmd = cmd + " --upload %s:/root/%s" % (f, os.path.basename(f))
for f in sortedlist:
   cmd = cmd + " --firstboot-command \"rpm -ivh /root/%s\" " % (os.path.basename(f))

cmd = cmd + " --firstboot-command \"tar xf /root/apic_gbp.tar -C /usr/share/openstack-puppet/modules\" "
cmd = cmd + " --firstboot-command \"ln -s /usr/share/openstack-puppet/modules/apic_gbp /etc/puppet/modules/apic_gbp\" "
cmd = cmd + " --firstboot-command \"rm -rf /usr/share/openstack-puppet/modules/neutron \" "
cmd = cmd + " --firstboot-command \"tar xf /root/neutron.tar -C /usr/share/openstack-puppet/modules\" "

local_cmd(cmd, cwd=patch_dir)
pipe = subprocess.Popen(". /home/stack/stackrc; env", stdout=subprocess.PIPE, shell=True)
output = pipe.communicate()[0]
env = dict((line.split('=', 1) for line in output.splitlines()))
os.environ.update(env)

imglist = local_cmd("openstack image list -f csv")
for li in imglist.split('\n')[1::]:
   if li:
       iid = li.split(',')[0][1:-1]
       local_cmd("openstack image delete %s" % iid)

#upload the new images
local_cmd("openstack overcloud image upload --image-path %s" % patched_images_dir, cwd='/home/stack')
local_cmd("openstack baremetal configure boot", cwd='/home/stack')


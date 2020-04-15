# python ./buildLists.py Xo wasperf@us.ibm.com Y29sZFMwZGE= latest default false

import urllib2
import re
import base64
import sys
import os
import tempfile

import ssl

##Added to solve build download issue
import ssl
context = ssl.SSLContext(ssl.PROTOCOL_TLSv1_2)

def getData(url):
  request = urllib2.Request(url)
  request.add_header("Authorization", "Basic %s" % base64string)
  return urllib2.urlopen(request, context=context).read()

stream = sys.argv[1]
intranetID = sys.argv[2]
ePassword = sys.argv[3]
buildLevel = sys.argv[4]
packageType = sys.argv[5]
urlAddress = sys.argv[6]
tempRootDir = sys.argv[7]
doDebug = sys.argv[8]
base64string = base64.encodestring('%s:%s' % (intranetID,base64.b64decode(ePassword))).replace('\n', '')
#Temporary Fix for the different URL aunthentication issue for CD runs
urlAddress = urlAddress.replace("libfsfe01.hursley.ibm.com", "libertyfs.hursley.ibm.com")
urlAddress = urlAddress.replace("libfsfe02.hursley.ibm.com", "libertyfs.hursley.ibm.com")

#Create temporary file
if (tempRootDir == 'false'):
  tempDir = tempfile.mkdtemp()
else:
  tempDir = tempfile.mkdtemp(dir=tempRootDir)
#Create download information text including build number
buildFile = '%s/BUILD.txt' % (tempDir)
tf = open(buildFile, "wt+")

pmgr = urllib2.HTTPPasswordMgrWithDefaultRealm()
if (urlAddress == 'false'):
  url = 'https://libertyfs.hursley.ibm.com/liberty/dev/%s/release' % (stream)
else:
  url = urlAddress
pmgr.add_password(None,url,intranetID,base64.b64decode(ePassword))
#Authentication for 2nd domain - temporary fix if liberty builds are consolidated to one domain
url2 = 'https://libfsfe02.hursley.ibm.com/liberty/dev/%s/release/' % (stream)
pmgr.add_password(None,url2,intranetID,base64.b64decode(ePassword))
handler = urllib2.HTTPBasicAuthHandler(pmgr)
opener = urllib2.build_opener(handler)
urllib2.install_opener(opener)
if (urlAddress == 'false'):
  #data = urllib2.urlopen(url).read()
  data = getData(url)
  if (doDebug == 'true'):
    print data
  if (buildLevel == 'latest'):
    link='last.good.build.html'
    tf.write('Requested Build Level : %s\n' % link)
    url='https://libertyfs.hursley.ibm.com/liberty/dev/%s/release/%s' % (stream,link)
    if (doDebug == 'true'):
      print url
    tf.write('Initial URL : %s\n' % url)
    #data = urllib2.urlopen(url).read()
    data = getData(url)
    if (doDebug == 'true'):
      print data
    url=(re.findall(r'<meta.*URL=(.*)\">',data))[0]
    if (doDebug == 'true'):
      print url
  else:
    link=re.findall(r'<td><a href=.*/\">(%s.*)/</a>' % buildLevel,data)
    url='https://libertyfs.hursley.ibm.com/liberty/dev/%s/release/%s' % (stream,link[0])
if (doDebug == 'true'):
   print url
if (packageType != 'default'  and packageType != 'tradelite' ):
  url = '%s/fe' % (url)
  tf.write('Adjusted URL : %s\n' % url)
  #data = urllib2.urlopen(url).read()
  data = getData(url)
  if (doDebug == 'true'):
     print data
  buildLevel=re.findall(r'<td><a href=.*/\">(.*).linux/</a>',data)
  print 'Build : %s' % buildLevel[0]
  url='%s/%s.linux/linux/zipper/externals/installables/' % (url,buildLevel[0])
  tf.write('Build Level : %s\n' % buildLevel[0])
  if (doDebug == 'true'):
    print url
  #data = urllib2.urlopen(url).read()
  data = getData(url)
  if (doDebug == 'true'):
    print data
  packageName=re.findall(r'<td><a href=.*\">(%s.*)</a>' % packageType,data)
  print 'Binary Name : %s' % packageName[0]
else:
  tf.write('Adjusted URL : %s\n' % url)
  buildLevel = re.findall(r'.*/(.*?-.*?)-.*',url)
  print 'Build : %s' % buildLevel[0]
  tf.write('Build Level : %s\n' % buildLevel[0])

  url = url.replace("libfsfe01.hursley.ibm.com", "libertyfs.hursley.ibm.com")
  url = url.replace("libfsfe02.hursley.ibm.com", "libertyfs.hursley.ibm.com")

  #data = urllib2.urlopen(url).read()
  request = urllib2.Request(url)
  base64string = base64.encodestring('%s:%s' % (intranetID,base64.b64decode(ePassword))).replace('\n', '')
  request.add_header("Authorization", "Basic %s" % base64string)
  data = urllib2.urlopen(request, context=context).read()
  if (doDebug == 'true'):
    print data
  if (packageType == 'tradelite'):
    buildExpression = 'wlp-tradelite-%s.zip' % buildLevel[0]
  else:
    buildExpression = 'wlp-%s.zip' % buildLevel[0]
  packageName=re.findall(r'<td><a href=.*\">(%s)</a>' % buildExpression,data)
  print 'Binary Name : %s' % packageName[0]
 
tf.write('Package Name : %s\n' % packageName[0])
tf.write('Installable URL : %s/%s\n' % (url,packageName[0]))
tf.close()
#Download the binary
#binary = urllib2.urlopen('%s/%s' % (url,packageName[0]))
request = urllib2.Request('%s/%s' % (url,packageName[0]))
base64string = base64.encodestring('%s:%s' % (intranetID,base64.b64decode(ePassword))).replace('\n', '')
request.add_header("Authorization", "Basic %s" % base64string)
binary = urllib2.urlopen(request, context=context)
####
installable = open ('%s/%s' % (tempDir,packageName[0]),"wb")
installable.write(binary.read())
installable.close()

data = [buildLevel[0],packageName[0],tempDir]
print data

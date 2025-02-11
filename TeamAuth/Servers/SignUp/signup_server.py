import socket
import threading	
import datetime
import time
import argparse
import cv2
import itertools
import numpy as np
import openface
import os
import firebase_admin
from firebase_admin import credentials
from firebase_admin import auth
import PIL
from PIL import Image
from PIL import ImageFile
import piexif

ImageFile.LOAD_TRUNCATED_IMAGES = True

### Init Our Firebase Admin SDK ###

cred = credentials.Certificate("/root/pie-auth-firebase-adminsdk-4rbmo-2d6c76da9f.json")
firebase_admin.initialize_app(cred)

###################################


### Packet IDS ###
# Packet format:  packet_id,id_token,data 

JOIN = 0				# Client is joining the server and the address from which this packet was sent will be their receiving address
IMAGE = 1				# Client wants to send us an image
IMAGE_RESPONSE = 2		# Our response to clients image (passed or failed face rec for signin server &  N/A for signup server)
IMAGE_PORT = 3			# Which port we want the image sent to
INVALID_TOKEN = 4		# Sent in response to join if the provide token is invalid
JOIN_SUCCESS = 5		# successful join

ADD_CLASS = 6
CREATE_SESSION = 7
JOIN_SESSION = 8
ADD_FEEDBACK = 9
CREATE_GROUP = 10
REPORT_ISSUE = 11

###################

PACKET_SIZE = 2048
DELIMITER = "|"
DATA_DELIMITER = "`"

class Client:
	def __init__(self, addr, id_token, uid):
		self.addr=addr
		self.uid=uid
		self.id_token=id_token

clients = []
		
public_ip = "172.17.0.2"

# Port for receiving commands from clients
command_port = 25595

# These are the ports available for receiving images and their availability (i.e. if they are not currently in use)
image_ports = {25585:True, 25586:True, 25587:True, 25588:True, 25589:True}

command_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)


modelDir = "/root/openface/models/"
dlibModelDir = os.path.join(modelDir, 'dlib')
openfaceModelDir = os.path.join(modelDir, 'openface')
imgDim = 96
align = openface.AlignDlib(os.path.join(dlibModelDir, "shape_predictor_68_face_landmarks.dat"))
net = openface.TorchNeuralNet(os.path.join(openfaceModelDir, 'nn4.small2.v1.t7'), imgDim)
def getRep(imgPath):
    
    bgrImg = cv2.imread(imgPath)
    if bgrImg is None:
        raise Exception("Unable to load image: {}".format(imgPath))
    rgbImg = cv2.cvtColor(bgrImg, cv2.COLOR_BGR2RGB)

    start = time.time()
    bb = align.getLargestFaceBoundingBox(rgbImg)
    if bb is None:
        raise Exception("Unable to find a face: {}".format(imgPath))
  
    print("  + Face detection took {} seconds.".format(time.time() - start))

    start = time.time()
    alignedFace = align.align(imgDim, rgbImg, bb,
                              landmarkIndices=openface.AlignDlib.OUTER_EYES_AND_NOSE)
    if alignedFace is None:
        raise Exception("Unable to align image: {}".format(imgPath))

    start = time.time()
    rep = net.forward(alignedFace)
    #print("  + OpenFace forward pass took {} seconds.".format(time.time() - start))
    #print("Representation:")
    #print(rep)
    #print("-----\n")
    return rep


try:
	command_socket.bind((public_ip, command_port))
except socket.error as err:
	print('Bind failed. Error Code : ' .format(err))
	
	
# NOTE!!!!! We 100% should be doing this client side, just doing this here for sake of demo
def scale_image(path):
	max_size = 512, 512
	image = Image.open(path)
	exif_dict = piexif.load(image.info["exif"])
	orientation = exif_dict["0th"][piexif.ImageIFD.Orientation]
	if   orientation == 3 :
		image=image.rotate(180, expand=True)
	elif orientation == 6 :
		image=image.rotate(270, expand=True)
	elif orientation == 8 :
		image=image.rotate(90, expand=True)
	image.thumbnail(max_size)
	image.save(path)


		
def client_recv_image(image_port, uid):
	
	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
	try:
		s.bind((public_ip, image_port))
	except socket.error as err:
		print('Bind failed. Error Code : ' .format(err))
	
	s.listen(10)
	(client, addr) = s.accept()
	
	image_stamp = "/root/userdata/temp/"+uid
	data = client.recv(1024)
	print ("Receiving image. Saving to " + image_stamp+".jpg")
	while (data):
		f = open(image_stamp+".jpg", 'ab+')
		f.write(data)
		data = client.recv(1024)
	
	scale_image(image_stamp+".jpg")
	
	feat_stamp = "/root/userdata/"+uid
	print ("Extracting feature data.")
	feats = np.asarray(getRep(image_stamp+".jpg"))
	f = open(feat_stamp+".txt", "w+")
	for fe in feats:
		f.write(str(fe)+"\n");
	f.close()
	
	s.close()
	
	image_ports[image_port] = True
	
	os.remove(image_stamp+".jpg")
	
def getPacketID(data):
	return int(data.split(",")[0])
	
def getIDToken(data):
	return data.split(",")[1]
	
def getData():
	return data.split(",")[2]
	
def lookUpUID(sessionID):
	# TODO look up UID in database given the sessionID
	return sessionID
	
def getOpenImagePort():
	while (1):
		for port in image_ports:
			if image_ports[port] == True:
				image_ports[port] = False
				return port
				
def formatPacket(packetID, data):
	return "{},{},".format(str(packetID), data)
	
def getClientFromIDToken(id_token):
	for c in clients:
		if c.id_token == id_token:
			return c
	return None
	
def getUIDFromToken(id_token):
	decoded_token = auth.verify_id_token(id_token)
	#determine if decoding failed and send INVALID_TOKEN back (make sure to set uid to something so that we know to *continue* the while loop)
	uid = decoded_token['uid']
	return uid
	
def client_accept():
	while (1):
		(data, addr) = command_socket.recvfrom(PACKET_SIZE)
		packetID = getPacketID(data)
		id_token = getIDToken(data)
		uid = getUIDFromToken(id_token)
		
		if (packetID == JOIN):
			clients.append(Client(addr, id_token, uid))
			print ("Client at {} joined with uid: {}".format(addr, uid))
			command_socket.sendto(formatPacket(JOIN_SUCCESS,""), addr)
		elif (packetID == IMAGE):
			image_port = getOpenImagePort()
			command_socket.sendto(formatPacket(IMAGE_PORT,image_port), addr)
			t = threading.Thread(target=client_recv_image, args=(image_port, uid))
			t.start();
		elif (packetID == ADD_CLASS):
		elif (packetID == CREATE_SESSION):
		elif (packetID == JOIN_SESSION):
		elif (packetID == ADD_FEEDBACK):
		elif (packetID == CREATE_GROUP):
		elif (packetID == REPORT_ISSUE):
			# addIssueReport(uid, 
		
		

com = ""
stopping = False
while (not(com=="quit")):
	com = raw_input("Command:  ")
	t = threading.Thread(target=client_accept)
	t.daemon = True
	if (com == "start"):
		t.start()
	if (com == "quit"):
		command_socket.close()
#!/usr/bin/env python
#-*- coding: UTF-8 -*-

# autor: Carlos Rueda
# date: 2015-09-06
# mail: carlos.rueda@deimos-space.com
# version: 1.0

##################################################################################
# version 1.0 release notes:
# Initial version
# Requisites:
#	library configobj 			To install: "apt-get install python-configobj"
##################################################################################

import sys
import os
import logging, logging.handlers
import json
import MySQLdb as mdb

########################################################################
# configuracion y variables globales
from configobj import ConfigObj
config = ConfigObj('./generate_windfarm.properties')

LOG = config['directory_logs'] + "/generate_windfarm.log"
LOG_FOR_ROTATE = 10

DB_FRONTEND_IP = config['mysql_host']
DB_FRONTEND_PORT = config['mysql_port']
DB_FRONTEND_NAME = config['mysql_db_name']
DB_FRONTEND_USER = config['mysql_user']
DB_FRONTEND_PASSWORD = config['mysql_passwd']

FILE_FOOTER = config['file_footer']
FILE_JSON = config['directory_json'] + config['file_json']

#PID = "/var/run/generate_windfarm/generate_windfarm"

########################################################################
# definicion y configuracion de logs
try:
    logger = logging.getLogger('generate_windfarm')
    loggerHandler = logging.handlers.TimedRotatingFileHandler(LOG , 'midnight', 1, backupCount=LOG_FOR_ROTATE)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    loggerHandler.setFormatter(formatter)
    logger.addHandler(loggerHandler)
    logger.setLevel(logging.DEBUG)
except Exception, error:
    logger.error( '------------------------------------------------------------------')
    logger.error( '[ERROR] Error writing log at ' + str(error))
    logger.error( '------------------------------------------------------------------')
    exit()
########################################################################


########################################################################

def main():
    while True:
        logger.debug("Generar la windfarm")
        
        featureVector = []
        lat_wm  = [0.0] * 100
        lon_wm  = [0.0] * 100

        con = mdb.connect(DB_FRONTEND_IP, DB_FRONTEND_USER, DB_FRONTEND_PASSWORD, DB_FRONTEND_NAME)
        cur = con.cursor()

        # Procesar los molinos
        sqlWindmill = "select NAME, LATITUDE, LONGITUDE, STATUS from WINDMILL"
        cur.execute(sqlWindmill)
        numrows = int(cur.rowcount)
        index = 1
        for i in range(numrows):
            row = cur.fetchone()
            name = row[0]
            latitude = row[1]
            longitude = row[2]
            status = row[3]

            lon_wm[index] = float(longitude)
            lat_wm[index] = float(latitude)
            index = index + 1

            vectorCoordinates = []
            vectorCoordinates.append(float(latitude))
            vectorCoordinates.append(float(longitude))

            # feature
            new_feature = {}
            new_feature['type'] = 'Feature'

            # geometria
            new_geometry = {}
            new_geometry['type'] = 'Point'
            new_geometry['coordinates'] = vectorCoordinates
            new_feature['geometry'] = new_geometry

    		# propiedades
            new_properties = {}
            new_properties['name'] = name
            new_properties['status'] = int(status)
            new_feature['properties'] = new_properties

            # añadir la feature
            featureVector.append(new_feature)

        # Procesar el cableado
        sqlWindmill = "select NAME, WM_A, WM_B, STATUS from CABLING"
        cur.execute(sqlWindmill)
        numrows = int(cur.rowcount)
        for j in range(numrows):
            row = cur.fetchone()
            name = row[0]
            wm_a = row[1]
            wm_b = row[2]
            status = row[3]

            lon1 = lon_wm[wm_a]
            lat1 = lat_wm[wm_a]
            lon2 = lon_wm[wm_a]
            lat2 = lat_wm[wm_b]

            vectorCoordinates1 = []
            vectorCoordinates1.append(lon1)
            vectorCoordinates1.append(lat1)
            vectorCoordinates2 = []
            vectorCoordinates2.append(lon2)
            vectorCoordinates2.append(lat2)
            vectorCoordinates = []
            vectorCoordinates.append(vectorCoordinates1)
            vectorCoordinates.append(vectorCoordinates2)

            # feature
            new_feature = {}
            new_feature['type'] = 'Feature'

            # geometria
            new_geometry = {}
            new_geometry['type'] = 'LineString'
            new_geometry['coordinates'] = vectorCoordinates
            new_feature['geometry'] = new_geometry

            # propiedades
            new_properties = {}
            new_properties['name'] = name
            new_properties['status'] = status
            new_feature['properties'] = new_properties

            # añadir la feature
            featureVector.append(new_feature)

        new_data = {}
        new_data['type'] = 'FeatureCollection'
        new_data['features'] = featureVector
        geojson_data = json.dumps(new_data)

        # volcar el json a fichero
        with open('./tmp.json', 'w') as outfile:
            json.dump(new_data, outfile)

        # eliminar los 2 ultimos caracteres para enganchar bien con footer
        with open('./tmp.json', 'rb+') as f:
            f.seek(0,2)                 # end of file
            size=f.tell()               # the size...
            f.truncate(size-2)          # truncate at that size - how ever many characters

        # Crear el fichero final
        origenes = sys.argv[1:]
        with open(FILE_JSON, 'wb') as dest:
            with open('./tmp.json') as o:
                dest.write(o.read())
            with open(FILE_FOOTER) as footer:
                dest.write(footer.read())

    sleep (60)

if __name__ == '__main__':
    main()

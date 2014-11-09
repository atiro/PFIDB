import sys,site
site.addsitedir('/var/www/pfi/bin/flask-env/lib/python2.7/site-packages')

#activate_this = '/var/www/pfi/bin/flask-env/bin/activate_this.py'
#execfile(activate_this, dict(__file__=activate_this))

sys.path.insert(0, '/var/www/pfi/bin/api')

debug = open("/tmp/debug", 'w')

debug.write("Sys path is" + ':'.join(sys.path))

debug.close()

from pfirest import app as application

#print dir(application)


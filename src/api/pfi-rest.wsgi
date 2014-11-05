import sys,os

PFI_REST_ENV = '/var/www/pfi/bin/flask-env'

activate_this = os.path.join(PFI_REST_ENV, 'bin', 'activate_this.py')
execfile(activate_this, dict(__file__=activate_this))

sys.path.insert(0, '/var/www/pfi/bin/api')

from pfi-rest import app as application

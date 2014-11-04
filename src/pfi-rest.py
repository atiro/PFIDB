from sqlalchemy import Column, Integer, String, create_engine, ForeignKey, Date, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship, backref
import flask
import flask.ext.sqlalchemy
import flask.ext.restless

#db.Model = declarative_base()
app = flask.Flask(__name__)
app.config['DEBUG'] = True
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///pfi_projects.db'
db = flask.ext.sqlalchemy.SQLAlchemy(app)

class Project(db.Model):
	__tablename__ = 'project'

	hmt_id = Column(Integer, primary_key=True)
	name = Column(String)
	department = Column(Integer, ForeignKey('department.id'))
    	department_key = relationship("Department")
	status = Column(String)
	date_ojeu = Column(Date)
	date_pref_bid = Column(Date)
	date_fin_close = Column(Date)
	date_cons_complete = Column(Date)
	date_ops = Column(Date)
	contract_years = Column(Integer)
	off_balance_IFRS = Column(Boolean)
	off_balance_ESA95 = Column(Boolean)
	off_balance_GAAP = Column(Boolean)
	capital_value = Column(Integer)
	spv = Column(Integer, ForeignKey('spv.id'))
	spv_key = relationship('SPV')
    	
	def __repr__(self):
		return "<Project(name='%s')>" % (self.name)

class Department(db.Model):
	__tablename__ = 'department'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class Authority(db.Model):
	__tablename__ = 'authority'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class Sector(db.Model):
	__tablename__ = 'sector'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class Constituency(db.Model):
	__tablename__ = 'constituency'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class Region(db.Model):
	__tablename__ = 'region'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class Company(db.Model):
	__tablename__ = 'company'

	id = Column(Integer, primary_key=True)
	name = Column(String)

class SPV(db.Model):
	__tablename__ = 'spv'

	id = Column(Integer, primary_key=True)
	spv_id = Column(Integer, primary_key=True)
	name = Column(String)
	address = Column(String)

class Equity(db.Model):
	__tablename__ = 'equity'

	id = Column(Integer, primary_key=True)
	proj_id = Column(Integer, ForeignKey('project.hmt_id'))
	company_id = Column(Integer, ForeignKey('company.id'))
	share = Column(Integer)
	change_2011 = Column(Boolean)
	
	project = relationship("Project", backref=backref('equity', order_by=share))
	company = relationship("Company", backref=backref('equity', order_by=share))

class Payment(db.Model):
	__tablename__ = 'payment'

	id = Column(Integer, primary_key=True)
	proj_id = Column(Integer, ForeignKey('project.hmt_id'))
	year = Column(Integer)
	estimated = Column(Integer)

	project = relationship("Project", backref=backref('payments', order_by=year))

	def __repr__(self):
		return "<Payment(proj_id='%s', year='%s', estimated='%s')>" % (self.proj_id, self.year, self.estimated)

db.create_all()

manager = flask.ext.restless.APIManager(app, flask_sqlalchemy_db=db)

manager.create_api(Project, methods=['GET'])
manager.create_api(Company, methods=['GET'])
manager.create_api(Payment, methods=['GET'])
manager.create_api(Region, methods=['GET'])

app.run()

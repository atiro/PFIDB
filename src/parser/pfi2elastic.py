import csv
from elasticsearch_dsl import DocType, String, Date, Nested, Boolean, Integer, Double
from elasticsearch_dsl.connections import connections

# Parse lines in CSV
# Fuzzy match investors to known list
# Create json doc
# send to elastic

connections.create_connection(hosts=
        ['search-pfi-4kfhhfprcclcblrr62xjzmtpbi.eu-west-1.es.amazonaws.com'],
        port=443,
        use_ssl=True
        )

class Project(DocType):
    hmt_id = Integer()
    project_name = String()

    department = String(index='not_analyzed')
    procuring_auth = String(index='not_analyzed')
    sector = String(index='not_analyzed')
    constituency = String(index='not_analyzed')
    region = String(index='not_analyzed')
    project_status = String(index='not_analyzed')

    date_ojeu = Date()
    date_pref_bid = Date()
    date_fin_close = Date()
    date_cons_complete = Date()
    date_operational = Date()

    contract_years = Integer()

    off_balance_GAAP = Boolean()
    off_balance_IFRS = Boolean()
    off_balance_ESA95 = Boolean()

    capital_value = Double()

    unitary_charge_payments = Nested(
            properties={
                'estimated': Boolean(),
                'year': Integer(),
                'payment': Double()
                }
            )

    equity_holders = Nested(
            properties={
                'name': String(index='not_analyzed'),
                'share': Double(),
                'from': Date(),
                'to': Date()
                }
            )

    spv_name = String(index='not_analyzed')
    spv_number = String(index='not_analyzed')
    spv_address = String()

    class Meta:
        index = 'pfi'

    def save(self, ** kwargs):
        return super().save(** kwargs)

    @classmethod
    def from_row(cls, data):
        project = Project(
            meta={'id': data[0]},
            hmt_id=data[0], 
            title=data[1])

        project.meta.id = data[0]

        project.department = data[2]
        project.procuring_auth = data[3]
        project.sector = data[4]
        project.constituency = data[5]
        project.region = data[6]
        project.project_status = data[7]

        project.date_ojeu = data[8]
        project.date_pref_bid = data[9]
        project.date_fin_close = data[10]
        project.date_cons_complete = data[11]
        project.date_operational = data[12]

        project.contract_years = data[13]

        if data[14].upper() == "OFF":
            project.off_balance_IFRS = False
        else:
            project.off_balance_IFRS = True

        if data[15].upper() == "OFF":
            project.off_balance_ESA95 = False
        else:
            project.off_balance_ESA95 = True

        if data[16].upper() == "OFF":
            project.off_balance_GAAP = False
        else:
            project.off_balance_GAAP = True

        project.capital_value = data[17]

        payment_year = 1992
        for i in range(0, 21):
            project.unitary_charge_payments.append(
                { 
                    'estimated': False,
                    'year': payment_year + i,
                    'payment': data[18+i]
                    }
                )

        for i in range(0, 45):
            project.unitary_charge_payments.append(
                { 
                    'estimated': True,
                    'year': payment_year + i,
                    'payment': data[40+i]
                    }
                )

        for i in range(0, 12, 2):
            project.equity_holders.append(
                {
                    'name': data[86+i],
                    'share': data[86+i+1]
                    }
                )

        project.spv_name = data[98]
        project.spv_number = data[99]
        project.spv_address = data[100]

        project.save()


def parse_pfi(filename=None):

    with open(filename) as csvfile:
        pfireader = csv.reader(csvfile, delimiter=',', quotechar='"')
        for pfi in pfireader:
            Project.from_row(pfi)

Project.init()

parse_pfi("test.csv")

import pandas as pd
from sqlalchemy import create_engine
import warnings
warnings.filterwarnings('ignore')

def run_etl(csv_path='data.csv', db_user='root', db_password='your_password', db_host='localhost', db_port='3306', db_name='ecommerce_db'):
    print('[1/4] Loading raw data...')
    df_raw = pd.read_csv(csv_path, encoding='ISO-8859-1')
    print(f'Raw records: {len(df_raw):,}')

    print('[2/4] Cleaning data...')
    df_clean = df_raw.dropna(subset=['CustomerID']).copy()
    df_clean['CustomerID'] = df_clean['CustomerID'].astype(int)
    df_clean = df_clean[(df_clean['Quantity'] > 0) & (df_clean['UnitPrice'] > 0)]
    df_clean['InvoiceDate'] = pd.to_datetime(df_clean['InvoiceDate'])
    df_clean['TotalAmount'] = (df_clean['Quantity'] * df_clean['UnitPrice']).round(2)
    df_clean['InvoiceMonth'] = df_clean['InvoiceDate'].dt.to_period('M').dt.to_timestamp()
    df_clean['Description'] = df_clean['Description'].astype(str).str.strip().str.title()
    df_clean['Country'] = df_clean['Country'].astype(str).str.strip()
    print(f'Clean records: {len(df_clean):,}')

    print('[3/4] Connecting to MySQL...')
    connection_url = f'mysql+mysqlconnector://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
    engine = create_engine(connection_url)
    
    print('[4/4] Ingesting into MySQL table: ecom_transactions...')
    df_clean.to_sql('ecom_transactions', con=engine, if_exists='replace', index=False, chunksize=10000)
    print('✅ ETL pipeline completed successfully!')

if __name__ == '__main__':
    run_etl()

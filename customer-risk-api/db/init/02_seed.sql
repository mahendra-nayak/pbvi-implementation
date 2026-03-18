-- Seed data for customers table.
-- All names are fictional. assessed_at uses fixed timestamps for determinism.
-- ON CONFLICT DO NOTHING makes the script idempotent.

INSERT INTO customers (customer_id, name, risk_tier, risk_factors, assessed_at) VALUES
  ('CUST-001', 'Margaret Holloway',  'LOW',    ARRAY['Long account tenure', 'Consistent repayment history', 'Low credit utilisation'],                                          '2025-01-15 09:00:00'),
  ('CUST-002', 'Daniel Osei',        'LOW',    ARRAY['Stable employment record', 'No missed payments in 5 years'],                                                              '2025-01-16 10:30:00'),
  ('CUST-003', 'Priya Nambiar',      'LOW',    ARRAY['Long account tenure', 'Consistent repayment history'],                                                                    '2025-01-17 11:00:00'),
  ('CUST-004', 'James Whitfield',    'LOW',    ARRAY['Low debt-to-income ratio', 'Stable employment record', 'Consistent repayment history'],                                   '2025-01-18 08:45:00'),
  ('CUST-005', 'Sofia Andersen',     'MEDIUM', ARRAY['Moderate credit utilisation', 'Single missed payment in 24 months'],                                                      '2025-02-01 09:15:00'),
  ('CUST-006', 'Kwame Asante',       'MEDIUM', ARRAY['Recent balance transfer', 'Moderate credit utilisation'],                                                                 '2025-02-03 14:00:00'),
  ('CUST-007', 'Lucia Ferreira',     'MEDIUM', ARRAY['Single missed payment in 24 months', 'Moderate debt-to-income ratio', 'Short account tenure'],                            '2025-02-05 10:00:00'),
  ('CUST-008', 'Thomas Bergmann',    'HIGH',   ARRAY['Late payment history', 'Debt-to-income ratio exceeds threshold', 'Multiple credit enquiries in 90 days'],                 '2025-03-01 09:00:00'),
  ('CUST-009', 'Aisha Kamara',       'HIGH',   ARRAY['Debt-to-income ratio exceeds threshold', 'County court judgement on record', 'Multiple credit enquiries in 90 days'],     '2025-03-04 13:30:00'),
  ('CUST-010', 'Ricardo Vásquez',    'HIGH',   ARRAY['Late payment history', 'Account in arrears', 'Debt-to-income ratio exceeds threshold', 'Recent default on record'],       '2025-03-07 11:45:00')
ON CONFLICT (customer_id) DO NOTHING;

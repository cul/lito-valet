# spec/requests/logs_spec.rb
#
# Logs require valet_admin?, which returns true for users with CUL_allstaff
# or CUL_dpts-dev affils (via admin?), or with the admin DB column set.
#
# IMPORTANT: affils must be saved to the DB with save! so that Devise
# reloads the correct values when it re-fetches the user on each request.
#
# The controller has four rendering paths:
#   1. No logset param           -> renders logset_list (list of available log sets)
#   2. logset + download param   -> renders index.csv.erb (CSV download)
#   3. logset, no year_month     -> renders month_list (year/month navigation)
#   4. logset + year_month       -> renders index (log entry datatable)

RSpec.describe 'Logs' do
  def admin_user
    user = FactoryBot.create(:happyuser)
    user.affils = ['CUL_allstaff']
    user.save!
    user
  end

  def create_log_entry(logset: 'ReCAP Loan', date: Time.zone.now)
    Log.create!(
      logset:          logset,
      logdata:         { bib_id: '123', title: 'Test Book', user: 'jdoe' }.to_json,
      remote_ip:       '127.0.0.1',
      browser_name:    'Test Browser',
      browser_version: '1.0',
      created_at:      date
    )
  end

  # --- Authentication ---

  it 'bounces unauthenticated user to sign-in page' do
    get logs_path
    expect(response).to redirect_to('http://www.example.com/sign_in')
  end

  it 'denies non-admin user with "Log access restricted"' do
    sign_in FactoryBot.create(:happyuser)
    get logs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Log access restricted')
  end

  # --- Path 1: no logset param -> logset list ---

  it 'renders logset list for admin user' do
    create_log_entry(logset: 'ReCAP Loan')
    sign_in admin_user
    get logs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('following logs are available')
    expect(response.body).to include('ReCAP Loan')
  end

  # --- Path 3: logset, no year_month -> month list ---

  it 'renders month list for a given logset' do
    create_log_entry(logset: 'ReCAP Loan', date: Time.zone.parse('2025-07-15'))
    sign_in admin_user
    get logs_path, params: { logset: 'ReCAP Loan' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ReCAP Loan')
    expect(response.body).to include('Logs are available for the following months')
    expect(response.body).to include('2025')
  end

  # --- Path 4: logset + year_month -> log entry datatable ---

  it 'renders log entries for a given logset and month' do
    create_log_entry(logset: 'ReCAP Loan', date: Time.zone.parse('2025-07-15'))
    sign_in admin_user
    get logs_path, params: { logset: 'ReCAP Loan', year_month: '2025-07' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ReCAP Loan')
    expect(response.body).to include('logs for 2025-07')
  end

  it 'renders empty datatable when no log entries exist for given month' do
    sign_in admin_user
    get logs_path, params: { logset: 'ReCAP Loan', year_month: '2099-01' }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('logs for 2099-01')
  end

  # --- Path 2: logset + download -> CSV ---

  it 'renders CSV download for a given logset and month' do
    create_log_entry(logset: 'ReCAP Loan', date: Time.zone.parse('2025-07-15'))
    sign_in admin_user
    get logs_path(format: :csv), params: { logset: 'ReCAP Loan', download: '2025-07' }
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include('text/csv')
    expect(response.headers['Content-Disposition']).to include('recap_loan_2025_07.csv')
  end
end

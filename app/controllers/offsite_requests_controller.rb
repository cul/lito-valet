class OffsiteRequestsController < ApplicationController
  before_action :authenticate_user!

  before_action :confirm_offsite_eligibility!, except: [:ineligible, :error]

  before_action :set_offsite_request, only: [:show, :edit, :update, :destroy]

  # before_filter :authenticate_user!, if: :devise_controller?

  # GET /offsite_requests
  # GET /offsite_requests.json
  def index
    redirect_to(action: 'bib')
  end

  # GET /offsite_requests/1
  # GET /offsite_requests/1.json
  def show
  end

  # Get a bib_id from the user
  def bib
    # If a bib is passed, use that instead of asking the user
    bib_id = params['bib_id']
    if bib_id.present?
      params = { bib_id: bib_id }
      return redirect_to holding_offsite_requests_path params
    end
  end

  # Given a bib_id, get a mfhd_id
  # Either select automatically,
  # or get from the user
  def holding
    bib_id = params['bib_id']
    if bib_id.blank?
      flash[:error] = 'Please supply a record number'
      return redirect_to bib_offsite_requests_path
    end

    @clio_record = ClioRecord.new_from_bib_id(bib_id)
    if @clio_record.blank?
      flash[:error] = "Cannot find record #{bib_id}"
      return redirect_to bib_offsite_requests_path
    end

    offsite_holdings = @clio_record.offsite_holdings
    if offsite_holdings.size.zero?
      flash[:error] = "The requested record (bib id #{bib_id}) has no offsite holdings available."
      return redirect_to bib_offsite_requests_path
    end

    if @clio_record.offsite_holdings.size == 1
      @holding = @clio_record.offsite_holdings.first
      mfhd_id = @holding[:mfhd_id]
      params = { bib_id: bib_id, mfhd_id: mfhd_id }
      # clear any leftover error message, let new page figure it out.
      flash[:error] = nil
      return redirect_to new_offsite_request_path params
    end

    # If we haven't redirected, then we'll render
    # a page to let the user pick which holding they want.
  end

  # Offsite Requests can be called with just barcode(s).
  # (E.g., for bound-with requsts)
  # Valet will then lookup the appropriate bib_id & mfhd_id
  def barcode
    barcode = params['barcode']
    wanted_title = params['wanted_title']
    wanted_enum_chron = params['wanted_enum_chron']

    if barcode.blank?
      flash[:error] = 'ERROR -- Not enough details to proceed with barcode request'
      redirect_to(error_offsite_requests_path) && return
    end

    @clio_record = ClioRecord.new_from_barcode(barcode)
    if @clio_record.blank?
      flash[:error] = "Cannot find any record for barcode #{barcode}"
      redirect_to(error_offsite_requests_path) && return
    end
    bib_id = @clio_record.id

    offsite_holdings = @clio_record.offsite_holdings
    if offsite_holdings.size.zero?
      flash[:error] = "The requested record (bib id #{bib_id}) has no offsite holdings available."
      redirect_to(error_offsite_requests_path) && return
    end

    # Identify the holding that contain an item with the passed-in barcode
    @holding = offsite_holdings.select do |holding|
      holding[:items].any? { |item| item[:barcode] == barcode }
    end.first # 'first' because select from array always returns array
    if @holding.blank?
      flash[:error] = "Cannot find any holding within bib #{bib_id} with the barcode #{barcode}."
      redirect_to(error_offsite_requests_path) && return
    end
    mfhd_id = @holding[:mfhd_id]

    # I now have my bib, holding, and barcode.
    # Pass all of it along to build the request form
    params = { bib_id: bib_id, mfhd_id: mfhd_id, barcode: barcode }
    if wanted_title.present?
      params[:wanted_title] = wanted_title || ''
      params[:wanted_enum_chron] = wanted_enum_chron || ''
    end
    redirect_to new_offsite_request_path params
  end

  # GET /offsite_requests/new
  # Needs to have a bib_id and mfhd_id,
  # if either is missing, bounce back to appropriate screen
  def new
    bib_id = params['bib_id']
    mfhd_id = params['mfhd_id']

    # These other params may be present, and need to be available in the form
    # For bound-with request, which title/enum_chron was actually wanted by patron?
    if params['wanted_title'].present?
      @wanted_title = params['wanted_title']
      @wanted_enum_chron = params['wanted_enum_chron'] || ''
    end
    # For barcode-targetted requests (like bound-with), which barcode(s)?
    @barcode = params['barcode'] if params['barcode'].present?

    if bib_id.blank?
      flash[:error] = 'Please supply a record number'
      return redirect_to bib_offsite_requests_path
    end
    if mfhd_id.blank?
      flash[:error] = 'Please specify a holding'
      params = { bib_id: bib_id }
      return redirect_to holding_offsite_requests_path params
    end

    @clio_record = ClioRecord.new_from_bib_id(bib_id)
    @clio_record.fetch_scsb_availabilty

    @holding = @clio_record.holdings.select { |h| h[:mfhd_id] == mfhd_id }.first

    # There's special view logic if the available-item list is empty.
    @available_items = get_scsb_available_items(@clio_record, @holding)

    @offsite_location_code = @holding[:location_code]
    @customer_code = @holding[:customer_code]
    @offsite_request = OffsiteRequest.new
  end

  # # GET /offsite_requests/1/edit
  # def edit
  # end

  # POST /offsite_requests
  # POST /offsite_requests.json
  def create
    @offsite_request_params = offsite_request_params
    @request_item_response = Recap::ScsbRest.request_item(@offsite_request_params) || {}

    begin
      log_request(@offsite_request_params, @request_item_response)
    rescue => ex
      Rails.logger.error "log_request(@offsite_request_params, @request_item_response) failed: #{ex.message}"
    end

    # Instead of raise/catch, just detect failed API call directly here
    if (status = @request_item_response[:status]) && (status != 200)
      render('api_error') && return
    end

    # Send confirmation email to patron
    from    = 'recap@library.columbia.edu'
    to      = current_user.email
    subject = confirmation_email_subject
    body    = confirmation_email_body
    ActionMailer::Base.mail(from: from, to: to, subject: subject, body: body).deliver_now

    # Then continue on to render the page
  end

  # PATCH/PUT /offsite_requests/1
  # PATCH/PUT /offsite_requests/1.json
  def update
    # respond_to do |format|
    #   if @offsite_request.update(offsite_request_params)
    #     format.html { redirect_to @offsite_request, notice: 'Offsite request was successfully updated.' }
    #     format.json { render :show, status: :ok, location: @offsite_request }
    #   else
    #     format.html { render :edit }
    #     format.json { render json: @offsite_request.errors, status: :unprocessable_entity }
    #   end
    # end
  end

  # DELETE /offsite_requests/1
  # DELETE /offsite_requests/1.json
  def destroy
    # @offsite_request.destroy
    # respond_to do |format|
    #   format.html { redirect_to offsite_requests_url, notice: 'Offsite request was successfully destroyed.' }
    #   format.json { head :no_content }
    # end
  end

  def ineligible
    # LIBSYS-2899 - COVID
    # To display the Valet-internal ineligible.html.erb file,
    # just remove the below line, to restore Rails default behavior.
    return redirect_to('https://library.columbia.edu/about/news/alert.html')
  end

  def error
  end

  private

  def confirm_offsite_eligibility!
    return redirect_to(ineligible_offsite_requests_path) unless current_user
    return redirect_to(ineligible_offsite_requests_path) unless current_user.offsite_eligible?

    # Some other basic conditions need to be satisfied....
    if current_user.barcode.blank?
      flash[:error] = 'ERROR -- Unable to determine barcode for current user'
      redirect_to(error_offsite_requests_path) && return
    end
  end

  def get_scsb_available_items(clio_record = nil, holding = nil)
    return [] if clio_record.blank? || holding.blank?

    available_items = []
    holding[:items].each do |item|
      scsb_availability = clio_record.scsb_availability[item[:barcode]]
      available_items << item if scsb_availability == 'Available'
    end
    available_items
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_offsite_request
    @offsite_request = OffsiteRequest.find(params[:id])
  end

  # Never trust parameters from the scary internet,
  # only allow the white list through.
  def offsite_request_params
    # Fill in ALL request params here,
    # permit some from form params,
    # merge in others from other application state
    application_params = {
      patronBarcode:   current_user.barcode,
      requestingInstitution: 'CUL'
    }

    params.permit(
      # Information about the request
      :requestType,
      :deliveryLocation,
      :emailAddress,
      # Optional EDD params
      :author,
      :chapterTitle,
      :volume,
      :issue,
      :startPage,
      :endPage,
      # Information about the requested item
      :itemOwningInstitution,
      :bibId,
      :titleIdentifier,
      :callNumber,
      itemBarcodes: []
    ).merge(application_params)
  end

  # WHAT ARE ALL THESE PARAMS FOR?
  # HERE ARE SOME INLINE COMMENTS FROM THE HTC WIKI:
  # https://htcrecap.atlassian.net/wiki/spaces/RTG/pages/25438542/Request+Item
  # {
  #   "author": "", // Author information of the bibliographic record.
  #   "bibId": "", // Bibliographic Id of the bibliographic record.
  #   "callNumber": "", // Call number details to ease process of retrieval.
  #   "chapterTitle": "", // Chapter title to ease fulfillment of EDD requests.
  #   "deliveryLocation": "PA", // Delivery location for physical retrievals.
  #   "emailAddress": "test@example.com", // Email address of the Patron. Mandatory in case of EDD requests.
  #   "endPage": "", // The end page for scanning in case of EDD requests. String input takes in any value.
  #   "issue": "", // Issue details to ease fulfillment of EDD requests.
  #   "itemBarcodes": [
  #     "PULTST54322" // Item Barcode. Multiple values (maximum of 20) allowed separated by comma (,) as long as they belong to the same bibliographic record, have same customer code and the same availability status.
  #   ],
  #   "itemOwningInstitution": "PUL", // Item owning institution. Possible values are PUL, CUL or NYPL.
  #   "patronBarcode": "45678913", // Patron Barcode.
  #   "requestNotes": "Test Request", // Request Notes can be leveraged to enter any notes relevant to the request.
  #   "requestType": "RETRIEVAL", // Request Type can either be 'RETRIEVAL', 'RECALL' or 'EDD'. Recall can be only done on a not available, checked out item.
  #   "requestingInstitution": "PUL", // Requesting Institution. The institution to which the requesting patron belongs to.
  #   "startPage": "", // The start page for scanning in case of EDD requests. String input takes in any value.
  #   "titleIdentifier": "", // This is used to send titles to use during creation of temporary records.
  #   "trackingId": "", // NYPL's ILS generated ID initiated on their side while placing hold used as a reference to return response in SCSB.
  #   "username": "admin", //User with Request permission
  #   "volume": "" // Volume information to ease fulfillment of EDD requests.
  # }

  def confirmation_email_subject
    subject = 'Offsite Request Submission Confirmation'
    if @request_item_response[:titleIdentifier]
      subject += " [#{@request_item_response[:titleIdentifier]}]"
    end

    subject += " (#{Rails.env})" if Rails.env != 'valet_prod'
    subject
  end

  def confirmation_email_body
    status = @request_item_response[:screenMessage]

    error = ''
    if @request_item_response[:success] != true
      error = <<-EOT
---------------------------------------------
ERROR : This submission was not successful.
Please check the message below.
---------------------------------------------
EOT
    end

    my_account_link = if params[:requestType] == 'RETRIEVAL'
                        '
                  You can check the status of your request via My Borrowing Account in CLIO:
                  http://www.columbia.edu/cgi-bin/cul/resolve?lweb0087

                  '
                      else
                        ''
    end

    body = <<-EOT
You have requested the following from Offsite:

TITLE : #{@request_item_response[:titleIdentifier]}
CALL NO : #{@offsite_request_params[:callNumber]}
BARCODE: #{(@offsite_request_params[:itemBarcodes] || []).join(', ')}

#{error}
Response message:
        #{status}


Requests submitted before 2:30pm Mon-Fri will be filled in one business day; all requests filled in two business days.

You will be contacted by email (to #{@request_item_response[:emailAddress]}) when the item is available.

In order to best serve the Columbia community, please request 20 items or fewer per day. Contact recap@library.columbia.edu with questions and comments.
#{my_account_link}
Thank you for using Offsite collections!
EOT
    body
  end

  def log_request(params, response)
    log_dir = get_log_dir
    return unless log_dir

    log_entry = get_log_entry(params, response)
    return unless log_entry

    # log_file = [ 'valet', Date.today.strftime('%Y%m'), 'log' ].join('.')
    # %Y%m%d           => 20071119                  Calendar date (basic)
    # %F               => 2007-11-19                Calendar date (extended)
    log_file = ['valet', Date.today.strftime('%F'), 'log'].join('.')
    File.open("#{log_dir}/#{log_file}", 'a') do |f|
      f.puts log_entry
    end
  end

  def get_log_dir
    log_dir = APP_CONFIG['log_directory']
    unless log_dir
      Rails.logger.error 'cannot log request - log_dir not given in app_config'
      return
    end
    unless Dir.exist?(log_dir)
      Rails.logger.error "cannot log request - can't find log_dir [#{log_dir}]"
      return
    end

    # # Full log_dir is top dir plus YYYY-MM subdir (e.g., "2017-07")
    # log_dir = log_dir + '/' + Date.today.strftime('%Y-%m')

    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    log_dir
  end

  # Given the request parameters and the SCSB API response,
  # build the log entry - a single line string
  def get_log_entry(params, response)
    fields = []

    # basic info
    fields.push 'datestamp=' + DateTime.now.strftime('%F %T')
    fields.push 'remoteIP=' + request.remote_ip

    # patron information
    fields.push 'requestingUni=' + current_user.login
    fields.push "patronBarcode=#{params[:patronBarcode]}"
    fields.push "emailAddress=#{params[:emailAddress]}"

    # SCSB API Response information
    # (also handle API failures, which return different fields)
    status = response[:success] || response[:error]
    status = 'false' if status.blank?
    fields.push "success=#{status}"
    message = response[:screenMessage] || response[:message] || ''
    fields.push "screenMessage=#{message.squish}"

    # Information about the request
    fields.push "requestType=#{params[:requestType]}"
    fields.push "deliveryLocation=#{params[:deliveryLocation]}"
    fields.push "requestingInstitution=#{params[:requestingInstitution]}"

    # Information about the requested item
    fields.push "itemOwningInstitution=#{params[:itemOwningInstitution]}"
    fields.push "itemBarcodes=#{(params[:itemBarcodes] || []).join(' / ')}"
    fields.push "bibId=#{params[:bibId]}"
    fields.push "callNumber=#{params[:callNumber]}"
    fields.push "titleIdentifier=#{params[:titleIdentifier]}"

    # Optional EDD params
    fields.push "author=#{params[:author]}"
    fields.push "chapterTitle=#{params[:chapterTitle]}"
    fields.push "volume=#{params[:volume]}"
    fields.push "issue=#{params[:issue]}"
    fields.push "startPage=#{params[:startPage]}"
    fields.push "endPage=#{params[:endPage]}"

    # Data fields could contain commas, or just about anything
    entry = fields.join('|')

    entry
  end
end

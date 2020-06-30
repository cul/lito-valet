module Service
  class Paging < Service::Base

    def setup_form_locals(bib_record)
      bib_record.fetch_voyager_availability
      
      locals = { bib_record: bib_record }
      locals
    end

    def send_emails(params, bib_record, current_user)
      mail_params = {
        bib_record: bib_record,
        barcodes:  params[:itemBarcodes],
        patron_uni: current_user.uid,
        patron_email: current_user.email,
        staff_email: APP_CONFIG[:paging][:staff_email]
      }
      # mail request to staff
      FormMailer.with(mail_params).paging.deliver_now
    end


    def get_confirmation_locals(params, bib_record, current_user)
      confirm_locals = {
        bib_record: bib_record,
        barcodes:  params[:itemBarcodes],
        patron_uni: current_user.uid,
        patron_email: current_user.email,
      }
      confirm_locals
    end

  end
end


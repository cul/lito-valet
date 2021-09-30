module Service
  class ItemFeedback < Service::Base
    
    FEEDBACK = {
      'retain' => 'retained on campus and not sent to Offsite (ReCAP)*',
      'rare'   => 'treated as a rare or unique item (non-circulating)*',
      'review' => 'reviewed for preservation (item in poor condition)*',
      'other'  => 'other (provide details below)',
    }

    def bib_eligible?(bib_record = nil)
      # Item Feedback is only mean for CUL-owned items cataloged in Voyager
      return true if bib_record.voyager?

      self.error = 'This item is not owned by Columbia Libraries.
        <br><br>  Please
        <strong>
        <a href="http://library.columbia.edu/services/askalibrarian.html">
          ask a librarian
        </a>
        </strong>
        or ask for assistance at a service desk.'
      false
    end

    # What information do we need to pass along for the initial form?
    def setup_form_locals(params, bib_record, current_user)
      locals = {
        bib_record: bib_record,
        feedback_options: FEEDBACK
      }
      locals
    end

    # - mail item-feedback details to staff, patron
    def send_emails(params, bib_record, current_user)
      item_feedback_params = get_item_feedback_params(params, bib_record, current_user)
      # mail search details to staff, patron
      FormMailer.with(item_feedback_params).item_feedback.deliver_now
    end
    
    # What information do we need on the confirmation web page?
    # (after the form is submitted and any emails are sent)
    def get_confirmation_locals(params, bib_record, current_user)
      get_item_feedback_params(params, bib_record, current_user)
    end

    # The same set of params will be used for both emails and the patron confirm page
    def get_item_feedback_params(params, bib_record, current_user)

      # The mfhd_id param identifies the which Holding the patron is asking about.
      # We'll pass along that holding's location details in the confirm email.
      holding = bib_record.holdings.select { |h| h[:mfhd_id] == params[:mfhd_id] }.first

      item_feedback_params = {
        bib_record: bib_record,
        location_name: holding[:location_display],
        location_code: holding[:location_code],
        feedback_text:  FEEDBACK[ params[:feedback] ],
        note:  params[:note],
        patron_email: current_user.email,
        staff_email: APP_CONFIG[:item_feedback][:staff_email]
      }
      item_feedback_params
    end
    
  end
end

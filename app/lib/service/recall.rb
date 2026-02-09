# https://s3.amazonaws.com/foliodocs/api/mod-circulation/p/circulation.html#circulation_requests_instances_post
#
# POST /circulation/requests/instances
# Creates a request for any item from the given instance ID
#
# POST /circulation/requests/instances
#
# {
#   "$schema": "http://json-schema.org/draft-04/schema#",
#   "title": "A request for any item based on the specified instance ID",
#   "description": "Request for any item selected from the instance that might be at a different location or already checked out to another patron",
#   "type": "object",
#   "properties": {
#     "requestDate": {
#       "description": "Date the request was made",
#       "type": "string",
#       "format": "date-time"
#     },
#     "requesterId": {
#       "description": "ID of the user who made the request",
#       "type": "string",
#       "pattern": "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"
#     },
#     "instanceId": {
#       "description": "ID of the instance being requested",
#       "type": "string",
#       "pattern": "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"
#     },
#     "requestLevel": {
#       "description": "Level of the request - Item or Title",
#       "type": "string",
#       "enum": ["Item", "Title"]
#     },
#     "requestExpirationDate": {
#       "description": "Date when the request expires",
#       "type": "string",
#       "format": "date-time"
#     },
#     "pickupServicePointId": {
#       "description": "The ID of the Service Point where this request can be picked up",
#       "type": "string",
#       "pattern": "^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$"
#     },
#     "patronComments": {
#       "description": "Comments made by the patron",
#       "type": "string"
#     }
#   },
#   "additionalProperties": false,
#   "required": [
#     "instanceId",
#     "requestLevel",
#     "requesterId",
#     "requestDate",
#     "pickupServicePointId"
#   ]
# }
# Example:
#
# {
#   "requestDate": "2017-07-29T22:25:37Z",
#   "requesterId": "21932a85-bd00-446b-9565-46e0c1a5490b",
#   "instanceId": "195efae1-588f-47bd-a181-13a2eb437701",
#   "requestLevel": "Item",
#   "requestExpirationDate": "2017-07-25T22:25:37Z",
#   "pickupServicePointId": "8359f2bc-b83e-48e1-8a5b-ca1a74e840de"
# }

module Service
  class Recall < Service::Base
    # Only bibs with checked-out items are eligible for Recall
    # (Not just not-available - status has to be "Checked Out")
    def bib_eligible?(bib_record = nil)
      # Only Columbia bibs are elibible for Recall
      if bib_record.owningInstitution != 'CUL'
        self.error = 'Recall requests can only be made for Columbia Library items.'
        return false
      end

      checked_out_count = 0
      item_statuses = bib_record.fetch_folio_availability()
      checked_out_count = item_statuses.values.count { |status| status == "Checked out" }

      if checked_out_count == 0
        self.error = "This record has no checked-out items.
        <br><br>
        Recall requests can only be made against checked-out items."
        return false
      end

      return true
    end

    # The Voyager Recall form looks like this:
    #      Place a Recall
    #      Title:             The essence of totalitarianism
    #      Instructions:      Please select an item.
    #      () Any Copy
    #      () This Copy:      c.1 0051570718 glx
    #
    #      Comment:
    #      Pick Up At:        Butler Circulation Desk
    #      Not Needed After:  2025-11-15
    #
    # The form will need bib details, copy details, and pickup locations
    def setup_form_locals(params, bib_record, current_user)
      locals = {
        bib_record:   bib_record,
        availability: bib_record.fetch_folio_availability
        # ... etc. ...
      }
      locals
    end

    # Service-specific form-param handling, before any email or confirm screen.
    # For Recall, make an API call to FOLIO
    # Here is the minimal data needed to successfully place a FOLIO Recall:
    #   {
    #       "requestLevel": "Item",
    #       "requestType": "Recall",
    #
    #       "instanceId": "0000072e-baa8-5478-bed1-54206c268977",
    #       "holdingsRecordId": "1ba62e86-97f1-5b74-a447-6be52ea78489",
    #       "itemId": "60c95ae4-a1f1-59d0-96c0-1f0c2dd85be8",
    #
    #       "requesterId": "5a05ac92-5512-5f1e-8198-31bcb9bf3397",
    #
    #       "fulfillmentPreference": "Hold Shelf",
    #       "pickupServicePointId": "cb457737-6d17-4046-8c98-315cd9b70f9f",
    #
    #       "requestDate": "2025-05-29"
    #   }
    # What comes to us from the form?  Just the bib and item ids.
    def service_form_handler(params)
      uni = params[:uni]
      user = Folio::Client.get_user_by_uni(uni)
      user_id = user["id"]

      # Use the bib ID to get the FOLIO Instance details
      bib_id = params[:id]
      instance = Folio::Client.get_instance_by_hrid(bib_id)
      instance_id = instance["id"]

      # Use the FOLIO Item UUID to get Item details, including Holding ID
      item_id = params[:item_id]
      item = Folio::Client.get_item(item_id)
      holdings_id = item['holdingsRecordId']

      today = Time.now.strftime("%Y-%m-%d")

      recall_params = {
        "requestLevel":          "Item",
        "requestType":           "Recall",

        "instanceId":            instance_id,
        "holdingsRecordId":      holdings_id,
        "itemId":                item_id,

        "requesterId":           user_id,

        "fulfillmentPreference": "Hold Shelf",
        # Hardcoded to Butler for today....
        "pickupServicePointId":  "cb457737-6d17-4046-8c98-315cd9b70f9f",

        "requestDate":           today
      }

      begin
        service_response = Folio::Client.post_item_recall(recall_params)
      rescue => ex
        # Failure!  Set error message, and return nil to signal failure.
        self.error = ex.message
        return
      end

      # Success!
      return service_response
    end

    # No email confirmaion for Recall at this time.
    # # We can send a confirm email to the user.
    # # Do we need to send an email to staff also, or does FOLIO handle that?
    # def send_emails(params, bib_record, current_user)
    #   recall_email_params = {}
    #   FormMailer.with(recall_email_params).recall.deliver_now
    # end

    # The confirmation page is what users are redirected to
    # after submitting the form.
    # What data elements do we want to display?
    def get_confirmation_locals(params, bib_record, current_user)
      # pull out the direct FOLIO response,
      # the confirm page will just echo some of this data back to the user
      service_response = params['service_response']

      # Link to "My Borrowing Account", appropriate for our environment
      clio = 'clio.columbia.edu'
      clio = 'clio-dev.cul.columbia.edu' if Rails.env == 'valet_dev'
      clio = 'clio-test.cul.columbia.edu' if Rails.env == 'valet_test'
      my_borrowing_account_url = 'http://' + clio + '/my_account'

      confirm_locals = {
        title:                    service_response['instance']['title'],
        call_number:              service_response['item']['callNumber'],
        barcode:                  service_response['item']['barcode'],
        pickup:                   service_response['pickupServicePoint']['discoveryDisplayName'],
        status:                   service_response['status'],
        my_borrowing_account_url: my_borrowing_account_url
      }
      confirm_locals
    end
  end
end

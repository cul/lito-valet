# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$ ->
  $('input:radio[name="requestType"]').change ->
    if this.checked && this.value == 'RETRIEVAL'
      # alert("retrieval!")
      $("select.retrieval-field").attr("disabled", false)
      $("input.edd-field").attr("disabled", true)
    if this.checked && this.value == 'EDD'
      # alert("edd!")
      $("select.retrieval-field").attr("disabled", true)
      $("input.edd-field").attr("disabled", false)


@validateOffsiteRequestForm = () ->

  # accumulate error messages as we go, alert once at the end
  errors = []
  
  # How many item barcodes are checked?
  checked_barcodes = $('input[name="itemBarcodes[]"]:checked')
  checked_barcodes_count = checked_barcodes.length

  # At least one must be checked
  if checked_barcodes_count < 1
    errors.push "  * You must select at least one barcode."

  # Don't allow more than 20 volumes at once
  if checked_barcodes_count > 20
    errors.push "  * Please do not request more than 20 volumes of a title per day.  If your research requires additional volumes, please contact for access:  recap@library.columbia.edu."

  # Which request type is selected?
  selected_request_type = $('input[name="requestType"]:checked').val()
  
  # One of them must be selected
  if selected_request_type == undefined
    errors.push "  * You must select a delivery method."

  # ==================================================
  # Validation rules for Electronic Document Delivery
  if selected_request_type == 'EDD'

    # EDD requests are made against a single volume
    if checked_barcodes_count > 1
      errors.push "  * When choosing 'Electronic' delivery, only one barcode may be selected."

    # Fragile material cannot be requested for Electronic Delivery
    if checked_barcodes.data('use-restriction') == 'FRGL'
      errors.push "  * The item you selected is only available via the 'Item to Library' delivery method."

    # A title must be given for all EDD requests
    if $('#chapterTitle').val().length == 0
      errors.push "  * When choosing 'Electronic' delivery, you must include a Title."

    # Start Page and End Page must both be filled in
    if $('#startPage').val().length == 0 || $('#endPage').val().length == 0
      errors.push "  * When choosing 'Electronic' delivery, you must include both a Start Page and an End Page.  If that information is not available, please enter 0."
  # ==================================================


  # IF WE HAVE ERRORS, alert the user, and fail the form validation
  if errors.length > 0
    message = "Please correct the following before submitting this form:\n\n"
    message = message + errors.join("\n")
    message = message + "\n\nFor citation assistance please contact a reference librarian:\n" 
    message = message + "http://library.columbia.edu/research/askalibrarian.html" 
    alert message
    return false

  # IF WE HAVE NO ERROR - return true, let the form proceed
  return true
  





$ ->
  # Fragile material should not be selectable when making EDD requests.
  # Hide all checkboxs with data-attribute use-restriction='FRGL'
  if $('input[name="requestType"]').val() == 'EDD'
    # alert("it's an EDD!")  # DEBUG
    $("input[data-use-restriction='FRGL']").hide()
    

######################################################
######################################################
######################################################

@validateRecapLoanRequestForm = () ->

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

######################################################
######################################################
######################################################

@validateRecapScanRequestForm = () ->

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

  # ==================================================
  # Validation rules for Electronic Document Delivery (a.k.a., Scan)

  # Is the Copyright Attestation checked?
  copyright_attestation = $('input[name="copyright_attestation"]:checked')
  if copyright_attestation.length == 0
    errors.push "  * You must check the box in the copyright acknowledgment."

  # EDD requests are made against a single volume
  if checked_barcodes_count > 1
    errors.push "  * Only one barcode may be selected for scan requests."

  # Fragile material cannot be requested for Electronic Delivery
  if checked_barcodes.data('use-restriction') == 'FRGL'
    errors.push "  * The item you selected is only available via the 'Item to Library' delivery method."

  # A title must be given for all EDD requests
  if $('#chapterTitle').val().length == 0
    errors.push "  * You must include a Title."

  # Start Page and End Page must both be filled in
  if $('#startPage').val().length == 0 || $('#endPage').val().length == 0
    errors.push "  * You must include both a Start Page and an End Page.  If that information is not available, please enter 0."
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

######################################################
######################################################
######################################################




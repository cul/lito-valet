
@validateItemFeedbackForm = () ->

  # accumulate error messages as we go, alert once at the end
  errors = []

  # If this bib has multiple holdings, they must select one of them
  if $('input:radio[name="mfhd_id"]').length > 0
    if $('input:radio[name="mfhd_id"]').is(':checked') == false
      errors.push "  * Please select a copy"


  # They must choose one of the Feedback options (retain, rare, etc.)
  if $('input:radio[name="feedback"]').is(':checked') == false
    errors.push "  * Please select a processing option"
  
  # IF WE HAVE ERRORS, alert the user, and fail the form validation
  if errors.length > 0
    message = "Please correct the following before submitting this form:\n\n"
    message = message + errors.join("\n")
    alert message
    return false

  # IF WE HAVE NO ERROR - return true, let the form proceed
  return true

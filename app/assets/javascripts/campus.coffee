@validateCampusForm = () ->

  # At least one campus must be checked
  if $('input:radio[name="campus"]').is(':checked') == false

    alert('You must select your primary campus affiliation.')
    return false

  return true

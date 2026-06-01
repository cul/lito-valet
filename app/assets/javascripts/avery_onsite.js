window.validateAveryOnsiteRequestForm = function() {

  // accumulate error messages as we go, alert once at the end
  var errors = [];

  // How many item barcodes in total?
  var barcodes = $('input[name="itemBarcodes[]"]');
  var barcodes_count = barcodes.length;
  // How many item barcodes are checked?
  var checked_barcodes = $('input[name="itemBarcodes[]"]:checked');
  var checked_barcodes_count = checked_barcodes.length;

  // If there are zero barcodes, that's OK for certain Avery items
  // But if there are barcodes, at least one needs to be checked
  if (barcodes_count > 0 && checked_barcodes_count < 1) {
    errors.push("  * You must select at least one barcode.");
  }

  // Avery Onsite use requires a date of visit
  if ($('#visitDate').val().length === 0) {
    errors.push("  * You must fill in the date of your onsite visit when making an On-Site Use request");
  }

  // IF WE HAVE ERRORS, alert the user, and fail the form validation
  if (errors.length > 0) {
    var message = "Please correct the following before submitting this form:\n\n";
    message = message + errors.join("\n");
    alert(message);
    return false;
  }

  // IF WE HAVE NO ERROR - return true, let the form proceed
  return true;
};

// When displaying the user-info panel inside
// a drop-down nav menu, don't close menu on click,
// leave open to let the user copy/paste/etc.
$(function() {
  $('.user-info').click(function(e) {
    e.stopPropagation();
  });
});

$(function() {
  $('#log_file_table').DataTable({
    pageLength: 100,
    lengthMenu: [ [20, 50, 100, -1], [20, 50, 100, "All"] ],
    dom: '<"top"flip>'
  });
});

// We don't want old Valet window hanging around.
$(function() {
  // The /timeout warning page closes after about a minute
  if (window.location.href.indexOf('/timeout') > -1) {
    var delay = 1 * (60 * 1000);
    setTimeout(function() { window.close('/timeout'); }, delay);
  // Any pop-up Valet page bounces to /timeout page after about an hour
  } else if (window.opener && window.opener !== window) {
    var delay = 60 * (60 * 1000);
    setTimeout(function() { window.location.replace('/timeout'); }, delay);
  }
});

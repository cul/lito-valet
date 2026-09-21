
document.addEventListener('DOMContentLoaded', function () {
  var tables = document.querySelectorAll('.reserves-datatable');
  if (tables.length === 0) { return; }

  tables.forEach(function (el) {
    new DataTable(el, { paging: false });
  });
});


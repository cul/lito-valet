
document.addEventListener('DOMContentLoaded', function () {

  var tables = document.querySelectorAll('.log-datatable');
  if (tables.length === 0) { return; }   // DataTables not loaded on this page

  tables.forEach(function (el) {
    new DataTable(el, {
      pageLength: 100,
      lengthMenu: [[20, 50, 100, -1], [20, 50, 100, 'All']],
      layout: {
        topStart:    ['search', 'pageLength'],
        topEnd:      ['info', 'paging'],
        bottomStart: null,
        bottomEnd:   null
      },
      order: []
    });
  });

});


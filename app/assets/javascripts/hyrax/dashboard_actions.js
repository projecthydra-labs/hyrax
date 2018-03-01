Blacklight.onLoad(function() {
  // toggle button on or off based on boxes being clicked
  $(".batch_document_selector, .batch_document_selector_all").bind('click', function(e) {
    var n = $(".batch_document_selector:checked").length;
    if (n>0 || ($('input#check_all').length && $('input#check_all')[0].checked)) {
      $('.sort-toggle').hide();
    } else {
      $('.sort-toggle').show();
    }
  });

  function show_details(item) {
    var array = item.id.split("expand_");
    if (array.length > 1) {
      var docId = array[1];
      $("#detail_" + docId + " .expanded-details").slideToggle();
      $(item).toggleClass('glyphicon-chevron-right glyphicon-chevron-down');
    }
  }

  // show/hide more information on the dashboard when clicking
  // plus/minus
  $('.glyphicon-chevron-right').on('click', function() {
    show_details(this);
    return false;
  });

  $('a').filter( function() {
      return $(this).find('.glyphicon-chevron-right').length === 1;
   }).on('click', function() {
    show_details($(this).find(".glyphicon-chevron-right")[0]);
    return false;
  });

  // Transition between time periods or object type via ajax request
  $('.admin-repo-charts').on('click', function(e) {
    e.preventDefault();

    var type_id = e.target.id;
    var field = $('#' + type_id);

    $(field).on('ajax:success', function(e, data) {
      var clicked_chart = field.parents().filter('ul').attr('id');

      $('#' + clicked_chart + '-table tbody').html(data.rows);
      $('#' + clicked_chart + ' a').removeClass('stats-selected');
      field.addClass('stats-selected');
    });
  });
});

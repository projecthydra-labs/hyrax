Blacklight.onLoad(function () {

  // change the action based which collection is selected
  // This expects the form to have a path that includes the string 'collection_replace_id'
  $('[data-behavior="updates-collection"]').on('click', function() {
      var string_to_replace = "collection_replace_id"
      var form = $(this).closest("form");
      var collection_id = $(".collection-selector:checked")[0].value;
      form[0].action = form[0].action.replace(string_to_replace, collection_id);
      form.append('<input type="hidden" value="add" name="collection[members]"></input>');
  });

  $('#add_collection_to_collection').on('click', function(e) {
      e.preventDefault();
      $('#add-collection-to-collection-modal').modal('show');
  });
});

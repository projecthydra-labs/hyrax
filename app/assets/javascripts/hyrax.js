//= require jquery-ui/core
//= require jquery-ui/widget
//= require jquery-ui/menu
//= require jquery-ui/autocomplete
//= require jquery-ui/position
//= require jquery-ui/effect
//= require jquery-ui/effect-highlight
//= require jquery-ui/sortable

//= require bootstrap/alert
//= require bootstrap/button
//= require bootstrap/collapse
//= require bootstrap/dropdown
//= require bootstrap/modal
//= require bootstrap/tooltip
// Popover requires that tooltip be loaded first
//= require bootstrap/popover
//= require bootstrap/tab
// Affix is used for the file manager
//= require bootstrap/affix

//= require select2
//= require fixedsticky

// Graphing libraries
//= require jquery.flot
//= require jquery.flot.time
//= require jquery.flot.selection
//= require morris/raphael-min
//= require morris/morris.min

//= require clipboard

// TODO: Consider removing? jcoyne thinks this is primarily needed for testing with PhantomJS:
//= require babel/polyfill
// CustomElements polyfill is a dependency of time-elements
//= require webcomponentsjs/0.5.4/CustomElements.min
//= require time-elements

//= require action_cable

//= require hyrax/monkey_patch_turbolinks
//= require hyrax/fileupload
// Provide AMD module support
//= require almond
//= require hyrax/notification
//= require hyrax/app
//= require hyrax/config
//= require hyrax/initialize
//= require hyrax/trophy
//= require hyrax/facets
//= require hyrax/featured_works
//= require hyrax/batch_select_all
//= require hyrax/browse_everything
//= require hyrax/search
//= require hyrax/content_blocks
//= require hyrax/ga_events
//= require hyrax/select_submit
//= require hyrax/tabs
//= require hyrax/user_search
//= require hyrax/proxy_rights
//= require hyrax/sorting
//= require hyrax/single_use_links_manager
//= require hyrax/dashboard_actions
//= require hyrax/batch
//= require hyrax/flot_stats
//= require hyrax/admin/admin_set_controls
//= require hyrax/admin/admin_set/group_participants
//= require hyrax/admin/admin_set/registered_users
//= require hyrax/admin/admin_set/participants
//= require hyrax/admin/admin_set/visibility
//= require hyrax/collections/editor
//= require hyrax/editor
//= require hyrax/editor/admin_set_widget
//= require hyrax/editor/linked_data_resource
//= require hyrax/admin/graphs
//= require hyrax/save_work
//= require hyrax/permissions
//= require hyrax/autocomplete
//= require hyrax/autocomplete/default
//= require hyrax/autocomplete/linked_data
//= require hyrax/autocomplete/resource
//= require hyrax/relationships
//= require hyrax/select_work_type
//= require hyrax/collections
//= require hydra-editor/hydra-editor
//= require nestable
//= require hyrax/file_manager/sorting
//= require hyrax/file_manager/save_manager
//= require hyrax/file_manager/member
//= require hyrax/file_manager
//= require hyrax/authority_select
//= require hyrax/sort_and_per_page
//= require hyrax/thumbnail_select
//= require hyrax/batch_select

// this needs to be after batch_select so that the form ids get setup correctly
//= require hyrax/batch_edit

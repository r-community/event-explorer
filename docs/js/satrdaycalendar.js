<script>

$(document).ready(function() {
		

		$('#mycalendar').fullCalendar({
			header: {
				left: 'prev,next today',
				center: 'title',
			right:"month,agendaWeek,agendaDay,listMonth"
			},
			height:650,
               // defaultDate: '2019-07-05',
			
			defaultView: 'month',
			editable: true,
                selectable:!0,
                selectHelper:!0,
			weekNumbers: true,
      navLinks: true, // can click day/week names to navigate views
      eventLimit: true, // allow "more" link when too many events

			eventSources: [

    // your event source
    {
      url: 'data/satrdays.json', // use the `url` property
    }


    // any other sources...

  ],
  eventRender: function(event, element, view) {
            element.qtip({
                content: '<b>' + event.title + '</b>' + '<br />' + event.additional_info + '<br />' + 'Owner: ' + event.owner + '<br />' + event.url,
                style: {
                     classes: 'qtip-white qtip-shadow'
                }, 
hide: {
        fixed: true
    },
                position: {
				at: 'top right',
target: 'mouse',
				my: 'top right',
				adjust: { 
mouse: false,
resize: true
}
                    
                }
            });
        }

});
	
	});
  
  
  </script>

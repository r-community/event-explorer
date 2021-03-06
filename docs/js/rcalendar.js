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
      //eventLimit: true, // allow "more" link when too many events

			eventSources: [

    {
      url: 'data/rugs_events.json', // use the `url` property
      color: '#ffffff',
      textColor:'blue'
    },
				{url: 'data/ropensci_jumpingR_events.json', // use the `url` property
      color:'blue',
					textColor:'white'},
				{url: 'data/meetingsR_events.json', // use the `url` property
      color: '#ffffff',
      textColor:'blue'},
				{
					url:'data/rstudio_events.json',
					color:'blue',
					textColor:'white'
				}


  ],
  timezone: 'local',
  timeFormat: 'hh:mm A',
  eventRender: function(event, element, view) {
            element.qtip({
                content: '<b>' + event.title + '</b>' + '<br />' + event.description +  '<br />' + event.url,
                style: {
                     classes: 'qtip-light qtip-youtube'
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
return $('#eventselector').val() === 'all' ||    event.title.toLowerCase().indexOf($('#eventselector').val()) >= 0
        }

});
	$('#eventselector').on('change',function(){ 
$('#mycalendar').fullCalendar('rerenderEvents');
 });
	});

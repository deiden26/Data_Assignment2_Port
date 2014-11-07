$(document).ready(function() {
	// Here we make each row in the Portfolios table
	// a link to that particular portfolio

$('.clickable-row tr').each(function(i,e)
   {
      $(e).children('td').click(function()
      {
         var name = $(this).parents("tr").not(":first-child").find("td:first").text();
         if(name)
         {
         	console.log(name);
            // $.ajax({
            // 	type: "POST",
            // 	url: "portfolio.pl",
            // 	data: {
            // 		act: "portfolio",
            // 		portName: name
            // 	},
            // 	success: function(data) {
            // 		console.log(data.response);
            // 		if (data.response == true) {
            // 			window.location.href = 'portfolio.pl';
            // 		} else {
            // 			// error
            // 		}
            // 	}
            // })
      		window.location.href = 'portfolio.pl?act=portfolio&portName=' + name;
            
         }              
      });
   });
});

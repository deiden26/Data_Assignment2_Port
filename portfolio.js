$(document).ready(function() {
	// Here we make each row in the Portfolios table
	// a link to that particular portfolio
   var pageType = $('.pageType').text();
   $('.clickable-row tr').each(function(i,e)
      {
         $(e).children('td').click(function()
         {
            var name = $(this).parents("tr").not(":first-child").find("td:first").text();
            if(name)
            {
         		console.log('uhhhh');
         		if (pageType == 'PortfolioList') {
         			console.log('portfoliolist');
         			window.location.href = 'portfolio.pl?act=portfolio&portName=' + name;
         		} else if (pageType == 'Portfolio') {
         			window.location.href = 'portfolio.pl?act=stock&stockName=' + name;
         		} 
            }      
         });
      });

   //Add datepicker to all input elements with id=datepicker
   $('.datePicker').fdatepicker()

   //Change data in covarTable based on input date range
   $('#covarTimeForm').submit( function (event) {
      event.preventDefault();
      var startDate = Date.parse($('#covarTimeForm #startDate').val())/1000;
      var endDate = Date.parse($('#covarTimeForm #endDate').val())/1000;
      var portName = $('#covarTimeForm #portName').val();
      $("#covarTable").load("portfolio.pl #covarTable",{
         act: "covar",
         portName: portName,
         startDate: startDate,
         endDate: endDate
      });
       return false;
   });
   //Change data in corrcoeffTable based on input date range
   $('#corrcoeffTimeForm').submit( function (event) {
      event.preventDefault();
      var startDate = Date.parse($('#corrcoeffTimeForm #startDate').val())/1000;
      var endDate = Date.parse($('#corrcoeffTimeForm #endDate').val())/1000;
      var portName = $('#corrcoeffTimeForm #portName').val();
      $("#corrcoeffTable").load("portfolio.pl #corrcoeffTable",{
         act: "corrcoeff",
         portName: portName,
         startDate: startDate,
         endDate: endDate
      });
       return false;
   });
});

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
   //
   $('#covarTimeForm').on('submit', function () {
       alert('Form submitted!');
       return false;
   });

   var generateLabels = function() {
      var interval = 1, // 1 day interval
         currentDate = new Date(document.getElementsByName('startDate')[0].value),
         endDate = new Date(document.getElementsByName('endDate')[0].value),
         between = [];
      
      while (currentDate <= endDate) {
         if (currentDate.getDay() != 0 && currentDate.getDay() != 6) {
            between.push(currentDate.toDateString());
         }
         currentDate.setDate(currentDate.getDate() + 1);
      }
      return between;
   }

   var history = $('#historyPage').text();
   if (history != '') {
      history = history.split(/\s+/);
      var labels = generateLabels();
      var data = {
         labels: labels,
         datasets: [{
            label: "Closing prices",
            strokeColor: "rgba(220,220,220,1)",
            pointColor: "rgba(220,220,220,1)",
            pointStrokeColor: "#fff",
            pointHighlightFill: "#fff",
            pointHighlightStroke: "rgba(220,220,220,1)",
            data: history
         }]
      };
      
      var ctx = document.getElementById("stockHistoryGraph").getContext("2d");
      var lineChart = new Chart(ctx).Line(data, {
         datasetFill: false
      });
   }

});

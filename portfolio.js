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

   var generateLabels = function(historyTs) {
      var interval = 1, // 1 day interval
         currentDate,
         dateString,
         between = [];
      
      for (var j=0; j<historyTs.length; j++) {
         currentDate = new Date(historyTs[j] * 1000 - 1000);
         dateString = (currentDate.getMonth() + 1) + '/' + currentDate.getDate() + '/' + currentDate.getFullYear();
         between.push(dateString);
      }
      
      if (between.length > 15) {
         var interval = 1;
         while (between.length / interval >= 15) {
            interval *= 2;
         }
         for (var i=0; i < between.length; i++) {
            if (i%interval != 0) {
               between[i] = "";
            }
         }
         showLabels = false;
      }
      return between;
   }

   var showLabels = true;
   var history = $('#historyPage').text();
   var historyTs = history.split(/\s+/);
   var historyClose = historyTs.splice(0, Math.floor(historyTs.length / 2));
   if (historyTs.length > 0) {
      var labels = generateLabels(historyTs);
      var data = {
         labels: labels,
         datasets: [{
            label: "Closing prices",
            strokeColor: "rgba(220,220,220,1)",
            pointColor: "rgba(220,220,220,1)",
            pointStrokeColor: "#fff",
            pointHighlightFill: "#fff",
            pointHighlightStroke: "rgba(220,220,220,1)",
            data: historyClose,
            scaleShowGridLines: false
         }]
      };
      
      var ctx = document.getElementById("stockHistoryGraph").getContext("2d");
      ctx.canvas.width = document.getElementById("stockHistoryGraphDiv").offsetWidth;
      Chart.defaults.global.showTooltips = false;
      Chart.defaults.global.animation = false;
      //Chart.defaults.global.scaleShow = false;
      var lineChart = new Chart(ctx).Line(data, {
         datasetFill: false,
         scaleShowGridLines: false,
         pointDot : false,
         bezierCurve: false
      });
   }

   // Now make a thingy that parses through prediction data
   var predictions = $('#predictions').text();
   if (predictions != '') {
      predictions = predictions.split(/\s+/);
      var estimated = [];
      for (var i=0, j=0; i < predictions.length; i++) {
         if (j == 2 && predictions[i] != 0) {
            estimated.push(predictions[i]);
         }
         j = (j + 1)%3;
      }
      var predLabels = [];
      for (i=0; i < estimated.length; i++) {
         predLabels[i] = i + 1;
      }
      var predData = {
         labels: predLabels,
         datasets: [{
            label: "Predictions",
            strokeColor: "rgba(220,220,220,1)",
            pointColor: "rgba(220,220,220,1)",
            pointStrokeColor: "#fff",
            pointHighlightFill: "#fff",
            pointHighlightStroke: "rgba(220,220,220,1)",
            data: estimated,
            scaleShowGridLines: false
         }] 
      }
      var ctxPred = document.getElementById("predictionsChart").getContext("2d");
      ctxPred.canvas.width = document.getElementById("predictionsChartDiv").offsetWidth;
      var predictionChart = new Chart(ctxPred).Line(predData, {
         datasetFill: false,
         scaleShowGridLines: false,
         pointDot : false,
         bezierCurve: false
      });
      if (predictionChart != null) {
         $("#predictionTitle").html("<h4>Predictions for the next " + estimated.length + " days:</h4>");
      }
   }

});

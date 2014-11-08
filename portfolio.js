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
});

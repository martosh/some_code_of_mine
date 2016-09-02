//Author MGrigorov 2015.07.03

var cdp = require('cdp').create();
var casper = cdp.casper;
var xPath = require('casper').selectXPath;
var d = require('utils');

casper.options.viewportSize = {width: 1300, height: 900};

//########### ADDITIONAL CONFIG ################

//cdp.debugOn();
// If don't want the script to stop on errors
//casper.options.exitOnError = 0;
//casper.options.onWaitTimeout = function() { };
//casper.options.onTimeout = function() { };
//var mouse = require("mouse").create(casper

//########### ACTUAL SCRIPT BODY ##############:
var my_url = 'http://www.bolsax.aspx'; // diff 
var my_root_url = 'http://www.bolsadesantiago.com';
var stopFilesCounter = 0; // counte 20 files and stop download
var maxDownloadedFiles = 20;

casper.start(my_url, function() {

//casper.capture('Show_me_whereIam.png');

	casper.wait(5000);

//	console.log ( "###############################");

	var page_end = 3;
	var pages_to_check = [];

	for (var i = 1; i <= page_end; i++) { //create [ 1 .. page_end] 
	   pages_to_check.push(i);
	}

//	d.dump(pages_to_check); casper.exit();
	casper.eachThen( pages_to_check, function (answer) {  //cycle the array 

			var page = answer.data;
		//	console.log ( "################################################################["+page+"]");

			casper.wait(5000);
			casper.thenEvaluate(function(page) {
					irHechos(page);
					console.log ( "################################################################################PAGE["+page+"]");
					}, page);

			casper.wait(5000);
			var allData = [];
			var my_data_array = [];


			if ( stopFilesCounter >= maxDownloadedFiles){ // return if maxFiles reached
				return;
			}

			casper.waitForSelector( xPath("//div[@class='bloqueHechos']"), //get data url time and title 
			    function pass () {
			        allData = casper.getElementsInfo( xPath("//div[@class='bloqueHechos']") );
//			        d.dump("Found Element");
		 		allData.forEach ( function (info){
					var html = info.html;
					var matchAll = /h4>([^<]+?)<\/h4><p\s+class=\"date">([^<]+?)<\/p>\s*<p>([^<]+?)<\/p><a[^>]*?href=\"([^"]+)/.exec(html);

					if ( matchAll != null ){
//						d.dump(  matchAll);
						if (  /\.pdf$/i.test(matchAll[4]) ) {
							var index_entry = cdp.index[my_root_url+matchAll[4]];

							if (typeof index_entry === "undefined"){
								var retrivedData = { title:matchAll[1], date:matchAll[2], text:matchAll[3], url:my_root_url+matchAll[4] };
								my_data_array.push(retrivedData);    
							}
//							d.dump(retrivedData);  // abc
//					 		casper.exit();
						}
					} 
				});

					var counter = 0;
				my_data_array.forEach( function(element){
							counter += 1;
							console.log("##########>>> Counter <<<###########["+counter+"] Pdf files found in page ["+page+"]");
							var filename = element.text.replace(/\s/g, "_");
							filename = filename.replace(/\,/g, "");
							casper.wait(2000);
                                                        console.log ( "########## FILENAME:"+counter+"_"+page+"@"+element.date+"@"+filename+'.pdf');
							if ( stopFilesCounter >= maxDownloadedFiles){
								return;
							}
							casper.then(cdp.setDownload(counter+"_"+page+"@"+element.date+"@"+filename+'.pdf'));
							casper.thenOpen(element.url);
							stopFilesCounter += 1;
				});

			    },

			    function fail () {
			        d.dump("Sorry CDP Did not load element xPath bloqueHechos");
			    });  

	});

});

casper.wait(5000);

cdp.run();


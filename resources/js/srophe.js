$(document).ready(function() {
// Main javascript functions used by place pages
// validate contact forms
$.validator.setDefaults({
	submitHandler: function() { 
	//Ajax submit for contact form
    $.ajax({
            type:'POST', 
            url: $('#email').attr('action'), 
            data: $('#email').serializeArray(),
            dataType: "html", 
            success: function(response) {
                var temp = response;
                if(temp == 'Recaptcha fail') {
                    alert('please try again');
                    Recaptcha.reload();
                }else {
                    $('div#modal-body').html(temp);
                    $('#email-submit').hide();
                    $('#email')[0].reset();
                }
               // $('div#modal-body').html(temp);
        }});
	}
});

$("#email").validate({
		rules: {
			recaptcha_challenge_field: "required",
			name: "required",
			email: {
				required: true,
				email: true
			},
			subject: {
				required: true,
				minlength: 2
			},
			comments: {
				required: true,
				minlength: 2
			}
		},
		messages: {
			name: "Please enter your name",
            subject: "Please enter a subject",
			comments: "Please enter a comment",
			email: "Please enter a valid email address",
			recaptcha_challenge_field: "Captcha helps prevent spamming. This field cannot be empty"
		}
});

//Reload only search-results-panel for research-tool form
$("#research-tool").submit(function(e){
    e.preventDefault();
    var url = $(this).attr('action')
    $.get(url, $(this).serialize(), function(data) {
        var content = $(data).find('#search-results-panel')
        $("#search-results-panel").html(content);
    }).fail( function(jqXHR, textStatus, errorThrown) {
        console.log(textStatus);
    });
});

//Reload only search-results-panel for research-tool form
$(".pagination a").click(function(e){
    e.preventDefault();
    var url = $(this).attr('href')
    $.get(url, $(this).serialize(), function(data) {
        var content = $(data).find('#search-results-panel')
        $("#search-results-panel").html(content);
    }).fail( function(jqXHR, textStatus, errorThrown) {
        console.log(textStatus);
    });
});

//Reload only search-results-panel for research-tool form
$(".facet-display a").click(function(e){
    e.preventDefault();
    var url = $(this).attr('href')
    $.get(url, $(this).serialize(), function(data) {
        var content = $(data).find('#search-results-panel')
        $("#search-results-panel").html(content);
    }).fail( function(jqXHR, textStatus, errorThrown) {
        console.log(textStatus);
    });
});
$("a.reset").click(function(e){
    window.location = window.location.pathname;
});
   
//Expand works authored-by in persons page
$('a.getData').click(function(event) {
    event.preventDefault();
    var title = $(this).data('label');
    var URL = $(this).data('ref');
    $("#moreInfoLabel").text(title);
    $('#moreInfo-box').load(URL + " #search-results");
});
    
$('#showSection').click(function(event) {
    event.preventDefault();
    $('#recComplete').load('/exist/apps/srophe/documentation/faq.html #selection');
});

//Changes text on toggle buttons, toggle funtion handled by Bootstrap
$('.togglelink').click(function(e){
    e.preventDefault();
    var el = $(this);
    if (el.text() == el.data("text-swap")) {
          el.text(el.data("text-original"));
        } else {
          el.data("text-original", el.text());
          el.text(el.data("text-swap"));
        }
});           

if (navigator.appVersion.indexOf("Mac") > -1 || navigator.appVersion.indexOf("Linux") > -1) {
    $('.get-syriac').show();
}

$(function () {
  $('[data-toggle="tooltip"]').tooltip()
})

//Clipboard function for any buttons with clipboard class. Uses clipboard.js
var clipboard = new Clipboard('.clipboard');

clipboard.on('success', function(e) {
    console.info('Action:', e.action);
    console.info('Text:', e.text);
    console.info('Trigger:', e.trigger);
    e.clearSelection();
});

clipboard.on('error', function(e) {
    console.error('Action:', e.action);
    console.error('Trigger:', e.trigger);
});

//Load flickr images
//.getFlickr
$('.getFlickrInfo').each(function(index, element) { 
    var url = $(this).data('url');
    var image = $(this).attr('data-image');
    $.get(url, function(data) {
        var description = $(data).find('description').text();
        var title = $(data).find('title').text();
        if (description === '') {
            desc = title;
        } else {
            desc = description;
        }
        $('[data-image="'+ image +'"]').each(function(){
            $(this).text(desc);
         });
        //$('#' + imageID).append("<span>" + desc + "</span>" );
        //$('#' + imageID).text("TEST1" + imageID );
        /*
        $('[data-image]').each(function(){
            $(this).text($(this).data(image));
         });
        */
        /*
         * $('<tr>').html(
                    $('td').text(item.rank),
                    $('td').text(item.content),
                    $('td').text(item.UID)
                ).appendTo('#records_table');
                
         * <a href="{$imageURL}" target="_blank">
                         <span class="helper"></span>
                         {
                            if($image-class = 'thumb-images') then <img src="{replace($imageURL,'b.jpg','t.jpg')}"/>
                            else <img src="{$imageURL}" />
                         }
                     </a>
                     <div class="caption">{if($desc != '') then $desc else $title}</div>
         * 
         */
           

    }).fail( function(jqXHR, textStatus, errorThrown) {
        console.log(textStatus);
    })
    //console.log('Hi there ' + url  )
   });
   
//Get citations from Zotero
$('#citationsBtn').click(function(e) {
    e.stopPropagation();
    e.preventDefault();
    $('#citationsDisplay').css('display','block');
});

$('#citationsHide').click(function(e) {
    e.stopPropagation();
    e.preventDefault();
    $('#citationsDisplay').css('display','none');
    $('#citationsDisplay div.content').empty();
});

$('#citeItemSelect').on('change', function (e) {
    e.stopPropagation();
    e.preventDefault();
    var href = $('#citationsBtn').attr('href');
    var style = $(this).val();
    $.get(href + '?format=bib&style=' + style, function( data ) {
        $( "#citationsDisplay div.content" ).html( data );
    }).fail(function() {
        $('#citationsDisplay div.content').empty();
        $( "#citationsDisplay div.content" ).html( 'Error' );
   });
   console.log(href + '?format=bib&style=' + style)
});

//end on load
});
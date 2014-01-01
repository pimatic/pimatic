/*
 * jQuery Mobile Framework : plugin to provide a simple popup (toast notification) similar to Android Toast Notifications
 * Copyright (c) jjoe64
 * licensed under LGPL
 * 
 */
(function($, undefined ) {

$.widget( "mobile.toast", $.mobile.widget, {
	options: {
		/**
		 * string|integer
		 * 'short', 'long' or a integer (milliseconds)
		 */
		duration: 'short',
		initSelector: ":jqmData(role='toast')"
	},
	_create: function(){
		var $el = this.element
		$el.addClass('ui-toast')
		$el.hide()
		self = this
		$('body').bind('showToast', function() {
		  self.cancel()
		})
	},
	/**
	 * fadeIn the toast notification and automatically fades out after the given time
	 */
	show: function() {
	  $('body').trigger('showToast') // cancels all active toasts
	  
		var $el = this.element
		
		var bw = $('body').width()
		var bh = $('body').height()
		
		var top = (bh*3/4) - $el.height()/2
		var left = bw/2 - $el.width()/2
		
		$el.css('top', top+'px')
		$el.css('left', left+'px')
		
		// fade in and fade out after the given time
		var millis = 3000
		if (this.options.duration === 'short') millis = 2000
		else if (this.options.duration === 'long') millis = 6000
		else if (! isNaN(this.options.duration)) millis = parseInt(this.options.duration)
		else jQuery.error('mobile.toast: options.duration has to be short, long or a integer value')
		
		$el.fadeIn().delay(millis).fadeOut('slow')
	},
	/**
	 * cancel and hides the toast
	 */
	cancel: function() {
	  var $el = this.element;
    $el.stop(true).hide()
	}
});
  
//auto self-init widgets
$( document ).bind( "pagecreate create", function( e ){
	$( $.mobile.toast.prototype.options.initSelector, e.target )
		.toast();
});
	
})( jQuery );


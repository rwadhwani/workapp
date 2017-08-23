/* ******************************************************************************************
 *	File		:	functions.js
 *	Purpose		:	JavaScript for Happy Toes UK
 *
 *	Author		:	Rajesh Wadhwani
 *	Created		:	14-Feb-2012
 *	Modified	:	
 *	Copyright	:	Room 101 Limited, 2012
 * ****************************************************************************************** */

/* Function will be called onfocus of inputbox field */
function hideText(eleID, defaultText) {
	if (document.getElementById(eleID).value == defaultText)
		document.getElementById(eleID).value = "";
}

/* Function will be called onblue of inputbox field */
function checkText(eleID, defaultText) {
	if (document.getElementById(eleID).value == "")
		document.getElementById(eleID).value = defaultText;
}

function performSearch(frm) {
	window.location = "/ExpenseBank/list/" + frm.search.value;
}

import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="ruby-cms--navigation-item-form"
export default class extends Controller {
  toggleFields(event) {
    const linkType = event.target.value;
    const urlField = document.getElementById("url-field");
    const pageField = document.getElementById("page-field");
    const routeField = document.getElementById("route-field");

    // Hide all fields
    if (urlField) urlField.style.display = "none";
    if (pageField) pageField.style.display = "none";
    if (routeField) routeField.style.display = "none";

    // Show relevant field
    switch (linkType) {
      case "url":
        if (urlField) urlField.style.display = "block";
        break;
      case "page":
        if (pageField) pageField.style.display = "block";
        break;
      case "route":
        if (routeField) routeField.style.display = "block";
        break;
    }
  }
}

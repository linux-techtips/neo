const codeInputArea = document.querySelector('code-input')
console.log(codeInputArea);

codeInput.registerTemplate("syntax-highlighted", 
  codeInput.templates.prism(Prism, 
  [
    new codeInput.plugins.Indent(true, 4)
  ])
);

console.log(codeInputArea.innerText)

// JavaScript to toggle dropdown visibility on click
document.addEventListener("DOMContentLoaded", function() {
  const dropdownButton = document.querySelector(".dropdown button");
  const dropdownContent = document.querySelector(".dropdown-content");

  dropdownButton.addEventListener("click", function(event) {
      // Prevent the event from bubbling up to the body (which could close it)
      event.stopPropagation();

      // Toggle the visibility of the dropdown
      dropdownContent.style.display = (dropdownContent.style.display === "block") ? "none" : "block";
  });

  // Close the dropdown if the user clicks anywhere outside of it
  document.addEventListener("click", function(event) {
      if (!dropdownButton.contains(event.target) && !dropdownContent.contains(event.target)) {
          dropdownContent.style.display = "none";
      }
  });
});

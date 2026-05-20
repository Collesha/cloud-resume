window.addEventListener('DOMContentLoaded', () => {
    getVisitorCount();
});

const functionApi = "https://mge5qn8ttd.execute-api.us-east-1.amazonaws.com/get-count"; 

function getVisitorCount() {
    let count = 0;
    fetch(functionApi)
        .then(response => {
            return response.json();
        })
        .then(response => {
            console.log("API Gateway response received:", response);
            count = response.count;
            document.getElementById('counter').innerText = count;
        })
        .catch(function(error) {
            console.log("Error fetching visitor count:", error);
            document.getElementById('counter').innerText = "error";
        });
}
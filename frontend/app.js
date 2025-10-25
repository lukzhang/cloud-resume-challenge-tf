// **CRITICAL:** Your working API Gateway URL
const API_URL = 'https://3cugs71ej9.execute-api.us-east-1.amazonaws.com/visits';

const getVisitCount = () => {
    fetch(API_URL)
        .then(response => {
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            return response.json();
        })
        .then(data => {
            // Update the counter element with the received count
            document.getElementById('counter').innerText = data.visits;
        })
        .catch(error => {
            console.error('Error fetching visitor count:', error);
            document.getElementById('counter').innerText = 'ERROR';
        });
};

// Call the function when the page loads
window.addEventListener('DOMContentLoaded', getVisitCount);

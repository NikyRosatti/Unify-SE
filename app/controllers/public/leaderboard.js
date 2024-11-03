document.addEventListener('DOMContentLoaded', () => {
    const userList = document.getElementById('user-list');
    const rows = userList.querySelectorAll('tr');
    
    rows.forEach((row, index) => {
        if (index >= 10) {
            row.style.display = 'none';
        }
    });
});

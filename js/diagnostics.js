const diagnostics_table = document.getElementById('diagnostics-table');

document.getElementById('diagnostics-toggle').addEventListener('click', function (e) {
    if (diagnostics_table.style.display) {
        diagnostics_table.style.display = '';
    } else {
        diagnostics_table.style.display = 'table';
    }
    e.preventDefault();
});

function getDiagnostics() {
    const tbody = diagnostics_table.getElementsByTagName('tbody')[0];

    function addFeature(name, notes) {
        const tr = document.createElement('tr');

        const td_feature = document.createElement('td');
        const td_available = document.createElement('td');
        const td_notes = document.createElement('td');

        td_feature.textContent = name;
        td_notes.textContent = notes;

        tr.appendChild(td_feature);
        tr.appendChild(td_available);
        tr.appendChild(td_notes);

        tbody.appendChild(tr);

        function setAvailability(value) {
            td_available.textContent = value ? 'yes' : 'unavailable';
        }

        return {
            setAvailability: setAvailability,
        };
    }

    return {
        addFeature: addFeature,
    };
}

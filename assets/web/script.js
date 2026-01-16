document.addEventListener('DOMContentLoaded', () => {
    fetchFiles();

    const dropZone = document.getElementById('drop-zone');
    const input = document.getElementById('fileInput');

    dropZone.addEventListener('click', () => input.click());

    input.addEventListener('change', (e) => {
        if (input.files.length) {
            uploadFile(input.files[0]);
        }
    });

    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('drop-zone--over');
    });

    ['dragleave', 'dragend'].forEach(type => {
        dropZone.addEventListener(type, () => {
            dropZone.classList.remove('drop-zone--over');
        });
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('drop-zone--over');
        if (e.dataTransfer.files.length) {
            input.files = e.dataTransfer.files;
            uploadFile(e.dataTransfer.files[0]);
        }
    });
});

async function fetchFiles() {
    const list = document.getElementById('file-list');
    try {
        const response = await fetch('/api/files');
        const files = await response.json();
        
        list.innerHTML = '';
        if (files.length === 0) {
            list.innerHTML = '<li class="file-item" style="justify-content: center; color: var(--text-secondary);">No files shared yet</li>';
            return;
        }

        files.forEach(file => {
            const li = document.createElement('li');
            li.className = 'file-item';
            
            const nameSpan = document.createElement('span');
            nameSpan.className = 'file-name';
            nameSpan.textContent = file.name;
            
            const a = document.createElement('a');
            a.href = `/download/${encodeURIComponent(file.name)}`;
            a.className = 'download-btn';
            a.textContent = 'Download';
            a.setAttribute('download', file.name);

            li.appendChild(nameSpan);
            li.appendChild(a);
            list.appendChild(li);
        });
    } catch (e) {
        list.innerHTML = '<li class="file-item" style="color: red;">Error loading files</li>';
        console.error(e);
    }
}

function uploadFile(file) {
    const status = document.getElementById('upload-status');
    const progressContainer = document.getElementById('progress-container');
    const progressBar = document.getElementById('progress-bar');
    
    status.textContent = `Uploading ${file.name}...`;
    status.style.color = 'var(--text-primary)';
    progressContainer.classList.remove('hidden');
    progressBar.style.width = '0%';

    const formData = new FormData();
    formData.append('file', file);

    const xhr = new XMLHttpRequest();
    xhr.open('POST', '/upload', true);

    xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
            const percentComplete = (e.loaded / e.total) * 100;
            progressBar.style.width = percentComplete + '%';
        }
    };

    xhr.onload = () => {
        if (xhr.status === 200) {
            status.textContent = 'Upload successful!';
            status.style.color = 'green';
            progressBar.style.width = '100%';
            setTimeout(() => {
                progressContainer.classList.add('hidden');
                status.textContent = '';
                fetchFiles();
            }, 2000);
        } else {
            status.textContent = 'Upload failed.';
            status.style.color = 'red';
        }
    };

    xhr.onerror = () => {
        status.textContent = 'Upload error.';
        status.style.color = 'red';
    };

    xhr.send(formData);
}

document.addEventListener('DOMContentLoaded', function() {
  const favoriteIcons = document.querySelectorAll('.favorite-icon');

  favoriteIcons.forEach(icon => {
    icon.addEventListener('click', function() {
      const documentId = this.getAttribute('data-document-id');
      const isFavorite = this.getAttribute('data-favorite') === 'true';

      if (isFavorite) {
        // Realiza una solicitud AJAX para eliminar de favoritos
        fetch(`/documents/${documentId}/unfavorite`, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
            'Content-Type': 'application/json'
          }
        }).then(response => {
          if (response.ok) {
            this.classList.remove('fas', 'active');
            this.classList.add('far');
            this.setAttribute('data-favorite', 'false');
          }
        }).catch(error => console.error('Error al eliminar de favoritos:', error));
      } else {
        // Realiza una solicitud AJAX para añadir a favoritos
        fetch(`/documents/${documentId}/favorite`, {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
            'Content-Type': 'application/json'
          }
        }).then(response => {
          if (response.ok) {
            this.classList.remove('far');
            this.classList.add('fas', 'active');
            this.setAttribute('data-favorite', 'true');
          }
        }).catch(error => console.error('Error al agregar a favoritos:', error));
      }
    });
  });
});

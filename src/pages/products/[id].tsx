import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import { Product } from '../../models/Product';
import { ProductService } from '../../services/productService';
import Link from 'next/link';
import Image from 'next/image';

const ProductDetailPage: React.FC = () => {
  const router = useRouter();
  const { id } = router.query;
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');
  const [showDeleteModal, setShowDeleteModal] = useState<boolean>(false);

  // Mock categories data - replace with actual API call
  const categoryNames: { [key: string]: string } = {
    '688e56485b11ec6a26b76f9b': 'Licores',
    'cat_adicionales': 'Adicionales',
    'cat_bebidas_calientes': 'Bebidas calientes',
    'cat_bebidas_frias': 'Bebidas frias',
    'cat_cafe': 'Cafe',
    'cat_carnes': 'Carnes',
    'cat_especiales': 'Especiales',
    'cat_parrilla': 'Parrilla'
  };

  useEffect(() => {
    if (id && typeof id === 'string') {
      loadProduct(id);
    }
  }, [id]);

  const loadProduct = async (productId: string) => {
    try {
      setLoading(true);
      const data = await ProductService.getProductById(productId);
      setProduct(data);
    } catch (err) {
      setError('Error loading product details');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async () => {
    if (!product) return;
    
    try {
      await ProductService.deleteProduct(product._id);
      router.push('/products');
    } catch (err) {
      setError('Error deleting product');
      console.error(err);
    }
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0,
    }).format(price);
  };

  const formatDate = (dateString?: string) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleDateString('es-CO', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  if (loading) return <div className="text-center py-8">Cargando producto...</div>;
  if (error) return <div className="text-center py-8 text-red-500">{error}</div>;
  if (!product) return <div className="text-center py-8">Producto no encontrado</div>;

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="flex justify-between items-start mb-8">
        <div>
          <Link href="/products" className="text-blue-500 hover:text-blue-600 mb-2 inline-block">
            ← Volver a productos
          </Link>
          <h1 className="text-3xl font-bold text-gray-800">{product.nombre}</h1>
          {!product.disponible && (
            <span className="inline-block bg-red-100 text-red-800 px-3 py-1 rounded-full text-sm font-medium mt-2">
              No disponible
            </span>
          )}
        </div>
        
        <div className="flex space-x-3">
          <Link
            href={`/products/edit/${product._id}`}
            className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg"
          >
            Editar
          </Link>
          <button
            onClick={() => setShowDeleteModal(true)}
            className="bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg"
          >
            Eliminar
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Product Image */}
        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          <div className="relative h-96 bg-gray-200">
            {product.imagenUrl ? (
              <Image
                src={product.imagenUrl}
                alt={product.nombre}
                fill
                className="object-cover"
              />
            ) : (
              <div className="flex items-center justify-center h-full text-gray-400">
                <div className="text-center">
                  <div className="text-6xl mb-2">📦</div>
                  <p>Sin imagen</p>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Product Details */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="space-y-6">
            {/* Basic Info */}
            <div>
              <h2 className="text-xl font-semibold mb-4">Información básica</h2>
              
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-600">Precio</label>
                  <p className="text-2xl font-bold text-green-600">{formatPrice(product.precio)}</p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-600">Costo</label>
                  <p className="text-lg font-semibold text-gray-800">{formatPrice(product.costo)}</p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-600">Categoría</label>
                  <p className="text-gray-800">{categoryNames[product.categoria] || 'Sin categoría'}</p>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-600">Tipo de producto</label>
                  <p className="text-gray-800 capitalize">{product.tipoProducto}</p>
                </div>
              </div>
            </div>

            {/* Description */}
            {product.descripcion && (
              <div>
                <label className="block text-sm font-medium text-gray-600 mb-2">Descripción</label>
                <p className="text-gray-800 leading-relaxed">{product.descripcion}</p>
              </div>
            )}

            {/* Stock and Unit */}
            {(product.stock !== undefined || product.unidadMedida) && (
              <div>
                <h3 className="text-lg font-semibold mb-3">Inventario</h3>
                <div className="grid grid-cols-2 gap-4">
                  {product.stock !== undefined && (
                    <div>
                      <label className="block text-sm font-medium text-gray-600">Stock</label>
                      <p className="text-gray-800">{product.stock}</p>
                    </div>
                  )}
                  
                  {product.unidadMedida && (
                    <div>
                      <label className="block text-sm font-medium text-gray-600">Unidad de medida</label>
                      <p className="text-gray-800">{product.unidadMedida}</p>
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* Ingredients (for combos) */}
            {product.ingredientes && product.ingredientes.length > 0 && (
              <div>
                <h3 className="text-lg font-semibold mb-3">Ingredientes</h3>
                <ul className="list-disc list-inside space-y-1">
                  {product.ingredientes.map((ingredient, index) => (
                    <li key={index} className="text-gray-800">{ingredient}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Timestamps */}
            <div>
              <h3 className="text-lg font-semibold mb-3">Información de sistema</h3>
              <div className="grid grid-cols-1 gap-2 text-sm text-gray-600">
                <div>
                  <span className="font-medium">ID:</span> {product._id}
                </div>
                {product.fechaCreacion && (
                  <div>
                    <span className="font-medium">Fecha de creación:</span> {formatDate(product.fechaCreacion)}
                  </div>
                )}
                {product.fechaActualizacion && (
                  <div>
                    <span className="font-medium">Última actualización:</span> {formatDate(product.fechaActualizacion)}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Delete Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <h3 className="text-lg font-semibold mb-4">Confirmar eliminación</h3>
            <p className="text-gray-600 mb-6">
              ¿Estás seguro de que quieres eliminar "{product.nombre}"? Esta acción no se puede deshacer.
            </p>
            <div className="flex justify-end space-x-3">
              <button
                onClick={() => setShowDeleteModal(false)}
                className="px-4 py-2 text-gray-600 hover:text-gray-800"
              >
                Cancelar
              </button>
              <button
                onClick={handleDelete}
                className="px-4 py-2 bg-red-500 hover:bg-red-600 text-white rounded"
              >
                Eliminar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ProductDetailPage;

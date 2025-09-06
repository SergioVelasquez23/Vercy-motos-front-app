import React, { useState, useEffect } from 'react';
import { Product } from '../models/Product';
import { ProductService } from '../services/productService';
import Link from 'next/link';
import Image from 'next/image';

interface Category {
  _id: string;
  nombre: string;
  descripcion?: string;
  imagenUrl?: string;
}

const ProductsPage: React.FC = () => {
  const [products, setProducts] = useState<Product[]>([]);
  const [filteredProducts, setFilteredProducts] = useState<Product[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [selectedCategory, setSelectedCategory] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string>('');

  // Mock categories data - you should replace this with actual API call
  const mockCategories: Category[] = [
    { _id: '688e56485b11ec6a26b76f9b', nombre: 'Licores' },
    { _id: 'cat_adicionales', nombre: 'Adicionales' },
    { _id: 'cat_bebidas_calientes', nombre: 'Bebidas calientes' },
    { _id: 'cat_bebidas_frias', nombre: 'Bebidas frias' },
    { _id: 'cat_cafe', nombre: 'Cafe' },
    { _id: 'cat_carnes', nombre: 'Carnes' },
    { _id: 'cat_especiales', nombre: 'Especiales' },
    { _id: 'cat_parrilla', nombre: 'Parrilla' }
  ];

  useEffect(() => {
    loadProducts();
    setCategories(mockCategories);
  }, []);

  useEffect(() => {
    filterProducts();
  }, [products, selectedCategory, searchQuery]);

  const loadProducts = async () => {
    try {
      setLoading(true);
      const data = await ProductService.getAllProducts();
      setProducts(data);
    } catch (err) {
      setError('Error loading products');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const filterProducts = () => {
    let filtered = products;

    // Filter by category
    if (selectedCategory) {
      filtered = filtered.filter(product => product.categoria === selectedCategory);
    }

    // Filter by search query
    if (searchQuery) {
      filtered = filtered.filter(product =>
        product.nombre.toLowerCase().includes(searchQuery.toLowerCase()) ||
        (product.descripcion && product.descripcion.toLowerCase().includes(searchQuery.toLowerCase()))
      );
    }

    setFilteredProducts(filtered);
  };

  const handleCategoryChange = (categoryId: string) => {
    setSelectedCategory(categoryId);
  };

  const handleSearch = (query: string) => {
    setSearchQuery(query);
  };

  const formatPrice = (price: number) => {
    return new Intl.NumberFormat('es-CO', {
      style: 'currency',
      currency: 'COP',
      minimumFractionDigits: 0,
    }).format(price);
  };

  if (loading) return <div className="text-center py-8">Cargando productos...</div>;
  if (error) return <div className="text-center py-8 text-red-500">{error}</div>;

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="flex justify-between items-center mb-8">
        <h1 className="text-3xl font-bold text-gray-800">Productos</h1>
        <Link href="/products/new" className="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded-lg">
          Agregar Producto
        </Link>
      </div>

      {/* Filters */}
      <div className="bg-white p-6 rounded-lg shadow-md mb-8">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Search */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Buscar productos
            </label>
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              placeholder="Buscar por nombre o descripción..."
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>

          {/* Category filter */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filtrar por categoría
            </label>
            <select
              value={selectedCategory}
              onChange={(e) => handleCategoryChange(e.target.value)}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="">Todas las categorías</option>
              {categories.map((category) => (
                <option key={category._id} value={category._id}>
                  {category.nombre}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Results counter */}
      <div className="mb-6">
        <p className="text-gray-600">
          Mostrando {filteredProducts.length} de {products.length} productos
        </p>
      </div>

      {/* Products grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
        {filteredProducts.map((product) => (
          <div key={product._id} className="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
            {/* Product image */}
            <div className="relative h-48 bg-gray-200">
              {product.imagenUrl ? (
                <Image
                  src={product.imagenUrl}
                  alt={product.nombre}
                  fill
                  className="object-cover"
                />
              ) : (
                <div className="flex items-center justify-center h-full text-gray-400">
                  <span>Sin imagen</span>
                </div>
              )}
              {!product.disponible && (
                <div className="absolute top-2 right-2 bg-red-500 text-white px-2 py-1 rounded text-sm">
                  No disponible
                </div>
              )}
            </div>

            {/* Product info */}
            <div className="p-4">
              <h3 className="font-semibold text-lg mb-2 line-clamp-1">{product.nombre}</h3>
              {product.descripcion && (
                <p className="text-gray-600 text-sm mb-2 line-clamp-2">{product.descripcion}</p>
              )}
              
              <div className="flex justify-between items-center mb-3">
                <span className="text-2xl font-bold text-green-600">
                  {formatPrice(product.precio)}
                </span>
                <span className="text-sm text-gray-500 capitalize">
                  {product.tipoProducto}
                </span>
              </div>

              {product.stock !== undefined && (
                <p className="text-sm text-gray-500 mb-3">
                  Stock: {product.stock} {product.unidadMedida || 'unidades'}
                </p>
              )}

              <div className="flex space-x-2">
                <Link
                  href={`/products/${product._id}`}
                  className="flex-1 bg-blue-500 hover:bg-blue-600 text-white text-center py-2 px-3 rounded text-sm"
                >
                  Ver detalles
                </Link>
                <Link
                  href={`/products/edit/${product._id}`}
                  className="bg-gray-500 hover:bg-gray-600 text-white py-2 px-3 rounded text-sm"
                >
                  Editar
                </Link>
              </div>
            </div>
          </div>
        ))}
      </div>

      {filteredProducts.length === 0 && (
        <div className="text-center py-12">
          <p className="text-gray-500 text-lg">No se encontraron productos</p>
        </div>
      )}
    </div>
  );
};

export default ProductsPage;

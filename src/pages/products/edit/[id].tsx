import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/router';
import ProductForm from '../../../components/ProductForm';
import { Product, UpdateProductRequest } from '../../../models/Product';
import { ProductService } from '../../../services/productService';

const EditProductPage: React.FC = () => {
  const router = useRouter();
  const { id } = router.query;
  const [product, setProduct] = useState<Product | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingProduct, setIsLoadingProduct] = useState(true);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    if (id && typeof id === 'string') {
      loadProduct(id);
    }
  }, [id]);

  const loadProduct = async (productId: string) => {
    try {
      setIsLoadingProduct(true);
      const data = await ProductService.getProductById(productId);
      setProduct(data);
    } catch (err) {
      setError('Error loading product details');
      console.error(err);
    } finally {
      setIsLoadingProduct(false);
    }
  };

  const handleSubmit = async (productData: UpdateProductRequest) => {
    if (!product) return;

    try {
      setIsLoading(true);
      setError('');
      
      const updatedProduct = await ProductService.updateProduct(product._id, productData);
      
      // Redirect to the product detail page
      router.push(`/products/${updatedProduct._id}`);
    } catch (err) {
      setError('Error updating product. Please try again.');
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleCancel = () => {
    if (product) {
      router.push(`/products/${product._id}`);
    } else {
      router.push('/products');
    }
  };

  if (isLoadingProduct) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center py-8">Cargando producto...</div>
      </div>
    );
  }

  if (!product) {
    return (
      <div className="container mx-auto px-4 py-8">
        <div className="text-center py-8 text-red-500">
          Producto no encontrado
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {error && (
        <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-6">
          <div className="flex">
            <div className="ml-3">
              <h3 className="text-sm font-medium text-red-800">Error</h3>
              <div className="mt-2 text-sm text-red-700">
                <p>{error}</p>
              </div>
            </div>
          </div>
        </div>
      )}

      <ProductForm
        product={product}
        onSubmit={handleSubmit}
        onCancel={handleCancel}
        isLoading={isLoading}
        isEdit={true}
      />
    </div>
  );
};

export default EditProductPage;
